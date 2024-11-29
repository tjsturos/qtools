#!/bin/bash

# Array to store frame data
declare -A frame_data
frame_numbers=()

install_package figlet figlet false

# Start monitoring logs
# Default number of lines to process
LINES=1000
ONE_SHOT=false
DEBUG=false
LIMIT=25
PRINT_QUIL=true

# Parse command line args
while [[ $# -gt 0 ]]; do
  case $1 in
    -l|--limit)
      LIMIT="$2"
      shift 2
      ;;
    -n|--lines)
      LINES="$2"
      shift 2
      ;;
    -o|--one-shot)
      ONE_SHOT=true
      shift
      ;;
    -d|--debug)
      DEBUG=true
      shift
      ;;
    --no-quil)
      PRINT_QUIL=false
      shift
      ;;
    *)
      shift
      ;;
  esac
done

get_hourly_reward() {
    local frame_reward=$1
    local frame_age=$2
    local reward=$(echo "$frame_reward / $frame_age * 3600" | bc)
    echo $reward
}

get_monthly_reward() {
    local frame_reward=$1
    local frame_age=$2
    local reward=$(echo "$frame_reward / $frame_age * 3600 * 24 * 30" | bc)
    echo $reward
}


# Function to calculate and display statistics
display_stats() {
    cd $QUIL_NODE_PATH
    if ! $ONE_SHOT; then
        clear
    fi

    if $DEBUG; then
        echo "Frame numbers: ${frame_numbers[@]}"
    fi

    # Check if qclient exists and get coin metadata
    if command -v qclient &> /dev/null; then
        # Get coin metadata and store in associative array
        while IFS= read -r line; do
            if $DEBUG; then
                echo "Processing metadata line: $line"
            fi
            if [[ $line =~ Frame[[:space:]]+([0-9]+) ]]; then
                if $DEBUG; then
                    echo "Found frame number: ${BASH_REMATCH[1]}"
                fi
                frame_num="${BASH_REMATCH[1]}"
                reward=$(echo "$line" | grep -o '[0-9.]\+[[:space:]]*QUIL' | grep -o '[0-9.]\+')
                frame_data[$frame_num,reward]="$reward"
            fi
        done < <(qclient token coins metadata 2>/dev/null)
    fi

    figlet -f small "Frame Statistics"
    
    total_duration=0
    total_started=0
    total_completed=0
    total_evaluation_time=0
    last_frame_num=0
    reward_total_count=0
    reward_total=0
    count=0
    output=()
    frame_outputs=()
    
    for frame_num in $(printf '%s\n' "${frame_numbers[@]}" | sort -n); do
        if [[ -n "${frame_data[$frame_num,received]}" && -n "${frame_data[$frame_num,proof_started]}" && -n "${frame_data[$frame_num,proof_completed]}" ]]; then
            local duration=$(printf "%.4f" $(echo "${frame_data[$frame_num,proof_completed]} - ${frame_data[$frame_num,received]}" | bc))
            local workers=${frame_data[$frame_num,proof_started,workers]}
            local ring=${frame_data[$frame_num,proof_completed,ring]}
            local received=$(printf "%.4f" ${frame_data[$frame_num,received]})
            local proof_started=$(printf "%.4f" ${frame_data[$frame_num,proof_started]})
            local proof_completed=$(printf "%.4f" ${frame_data[$frame_num,proof_completed]})
            local reward=$(printf "%.4f" ${frame_data[$frame_num,reward]})
            if [ "$reward" = "0.0000" ]; then
                reward=""
            fi

            if [ "$reward" != "" ]; then
                reward_total_count=$(echo "$reward_total_count + 1" | bc)
                reward_total=$(echo "$reward_total + $reward" | bc)
            fi

            last_frame_num=$frame_num
            if $PRINT_QUIL; then
                frame_outputs+=("Frame $frame_num ($workers workers, ring $ring): $received -> $proof_started -> $proof_completed ($duration seconds${reward:+, $reward QUIL received})")
            else
                frame_outputs+=("Frame $frame_num ($workers workers, ring $ring): $received -> $proof_started -> $proof_completed ($duration seconds)")
            fi
            
            total_duration=$(echo "$total_duration + $duration" | bc)
            total_started=$(echo "$total_started + $proof_started" | bc)
            total_completed=$(echo "$total_completed + $proof_completed" | bc)
            evaluation_time=$(echo "$proof_started - $received" | bc)
            total_evaluation_time=$(echo "$total_evaluation_time + $evaluation_time" | bc)
            
            ((count++))
        fi
    done
    output+=("Last Updated: $(date '+%Y-%m-%d %H:%M:%S')")
    output+=("Peer ID: $(qtools peer-id)")
    output+=("Account: $(qtools account)")
    if $PRINT_QUIL; then
        output+=("Account Balance: $(qtools balance)")
    fi
    output+=("")
    output+=("=======================")
    output+=("${frame_outputs[@]}")
    
    if [ $count -gt 0 ]; then
        
        avg_duration=$(echo "scale=2; $total_duration / $count" | bc)
        avg_started=$(echo "scale=2; $total_started / $count" | bc)
        avg_completed=$(echo "scale=2; $total_completed / $count" | bc)
        avg_evaluation_time=$(echo "scale=2; $total_evaluation_time / $count" | bc)
        reward_landing_rate=$(echo "scale=2; $reward_total_count / $count" | bc)
        output+=("")
        output+=("$(figlet -f banner "Frame ${last_frame_num}")")
        output+=("Average received timestamp: $avg_started seconds")
        output+=("Average proof duration: $avg_duration seconds") 
        output+=("Average completed timestamp: $avg_completed seconds")
        output+=("Average evaluation time: $avg_evaluation_time seconds")
        output+=("")
        output+=("Total frames processed: $count (limit: $LIMIT)")
        output+=("Total reward received: $reward_total QUIL")
        output+=("Reward landing rate: $reward_landing_rate (landed proofs/frame count)")

        if $PRINT_QUIL; then
            avg_reward=$(echo "scale=2; $reward_total / $count" | bc)
            hourly_reward=$(get_hourly_reward $reward_total $avg_duration)
            monthly_reward=$(get_monthly_reward $reward_total $avg_duration)
            output+=("")
            output+=("Average reward per frame: $avg_reward QUIL")
            output+=("Hourly reward: $hourly_reward QUIL")
            output+=("Monthly reward: $monthly_reward QUIL")
        fi
    else
        output+=("No frames processed")
    fi
    output+=("=======================")

    printf '%s\n' "${output[@]}"
}

# Function to process a single log line and record stats
process_log_line() {
    local line="$1"
    local log_type="$2"

    # Skip if line doesn't contain frame_number
    if ! [[ "$line" =~ "frame_number" ]]; then
        return
    fi

    # Extract frame number first and validate
    frame_num=$(echo "$line" | jq -r '.frame_number')
    if [[ -z "$frame_num" || "$frame_num" == "null" ]]; then
        return
    fi

    if [[ $line =~ "evaluating next frame" ]]; then
        frame_age=$(echo "$line" | jq -r '.frame_age')
        if [[ "$log_type" != "historical" ]]; then
            echo "Received frame $frame_num (frame age $frame_age):"
        fi
        
        frame_data[$frame_num,received]=$frame_age
        # Add to frame numbers array if not already present
        if [[ ! " ${frame_numbers[@]} " =~ " ${frame_num} " ]]; then
            frame_numbers+=($frame_num)
            if $DEBUG; then
                echo "Frame numbers after adding $frame_num: ${frame_numbers[@]}"
            fi
        fi
        
    elif [[ $line =~ "creating data shard ring proof" ]]; then
        frame_age=$(echo "$line" | jq -r '.frame_age')
        workers=$(echo "$line" | jq -r '.active_workers')
        if [[ "$log_type" != "historical" ]]; then
            echo "Started creating proof for frame $frame_num ($workers workers, frame age $frame_age):"
        fi
        frame_data[$frame_num,proof_started]=$frame_age
        frame_data[$frame_num,proof_started,workers]=$workers
        
    elif [[ $line =~ "submitting data proof" ]]; then
        frame_age=$(echo "$line" | jq -r '.frame_age')
        ring_size=$(echo "$line" | jq -r '.ring')
        if [[ "$log_type" != "historical" ]]; then
            echo "Completed creating proof for frame $frame_num ($ring_size ring, frame age $frame_age):"
        fi
        frame_data[$frame_num,proof_completed]=$frame_age
        frame_data[$frame_num,proof_completed,ring]=$ring_size

        if [[ "$log_type" != "historical" ]]; then
            display_stats
        fi
    fi
}

truncate_frame_records() {
    # Sort frame numbers in ascending order
    IFS=$'\n' sorted_frames=($(sort -n <<<"${frame_numbers[*]}"))
    unset IFS

    # If we have more frames than the limit
    if [ "${#sorted_frames[@]}" -gt "$LIMIT" ]; then
        # Calculate how many frames to remove
        remove_count=$((${#sorted_frames[@]} - $LIMIT))
        
        # Remove oldest frames from frame_numbers array
        for ((i=0; i<remove_count; i++)); do
            old_frame=${sorted_frames[i]}
            
            # Remove from frame_numbers array
            frame_numbers=("${frame_numbers[@]/$old_frame}")
            
            # Remove all associated data for this frame
            unset frame_data[$old_frame,received]
            unset frame_data[$old_frame,proof_started]
            unset frame_data[$old_frame,proof_started,workers]
            unset frame_data[$old_frame,proof_completed]
            unset frame_data[$old_frame,proof_completed,ring]
        done

        # Clean up frame_numbers array (remove empty elements)
        frame_numbers=("${frame_numbers[@]}")
    fi
}

echo "Processing historical logs (last $LINES lines)..."
# Process historical logs first
while read -r line; do
    process_log_line "$line" "historical"
done < <(journalctl -u $QUIL_SERVICE_NAME -r -n "$LINES" -o cat)

if $DEBUG; then
    echo "Frame numbers after processing historical logs: ${frame_numbers[@]}"
fi

display_stats

if $ONE_SHOT; then
    exit 0
fi

# Now follow new logs
while read -r line; do
    process_log_line "$line" "new"
    truncate_frame_records
done < <(journalctl -f -u $QUIL_SERVICE_NAME -o cat)
