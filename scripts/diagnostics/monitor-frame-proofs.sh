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
UPDATE_INTERVAL=25 # Default update interval in seconds
AUTO_RESTART=false
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
    -u|--update)
      UPDATE_INTERVAL="$2"
      shift 2
      ;;
    --auto-restart)
      AUTO_RESTART=true
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
    if $DEBUG; then
        echo "Calculating hourly reward: $frame_reward / $frame_age"
    fi
    local reward=$(echo "scale=10; $frame_reward * 3600 / $frame_age" | bc)
    echo $reward
}

get_daily_reward() {
    local frame_reward=$1
    local frame_age=$2
    local reward=$(echo "scale=10; $frame_reward * 3600 * 24 / $frame_age" | bc)
    echo $reward
}

get_monthly_reward() {
    local frame_reward=$1
    local frame_age=$2
    if $DEBUG; then
        echo "Calculating monthly reward: $frame_reward * 3600 * 24 * 30 / $frame_age"
    fi
    local reward=$(echo "scale=10; $frame_reward * 3600 * 24 * 30 / $frame_age" | bc)
    echo $reward
}

CURRENT_TIMESTAMP=0
LAST_FRAME_RECEIVED_TIMESTAMP=0
LAST_RESTART_TIMESTAMP=0
RESTART_COUNT=0

# Function to calculate and display statistics
display_stats() {
    cd $QUIL_NODE_PATH
    
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

    total_duration=0
    total_started=0
    total_completed=0
    total_evaluation_time=0
    last_frame_num=0
    reward_total_count=0
    reward_total=0
    count=0
    no_proof_count=0
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
                frame_outputs+=("Frame $frame_num (workers:$workers, ring:$ring): $received -> $proof_started -> $proof_completed (${duration}s${reward:+, $reward QUIL})")
            else
                frame_outputs+=("Frame $frame_num (workers:$workers, ring:$ring): $received -> $proof_started -> $proof_completed (${duration}s)")
            fi
            
            total_duration=$(echo "$total_duration + $duration" | bc)
            total_started=$(echo "$total_started + $proof_started" | bc)
            total_completed=$(echo "$total_completed + $proof_completed" | bc)
            evaluation_time=$(echo "$proof_started - $received" | bc)
            total_evaluation_time=$(echo "$total_evaluation_time + $evaluation_time" | bc)
            
            ((count++))
        else
            ((no_proof_count++))
            if [[ -n "${frame_data[$frame_num,received]}" && -z "${frame_data[$frame_num,proof_started]}" ]]; then
                local received=$(printf "%.4f" ${frame_data[$frame_num,received]})
                frame_outputs+=("Frame $frame_num: Recieved at $received (no proof started)")
                ((count++))
            elif [[ -n "${frame_data[$frame_num,proof_started]}" && -z "${frame_data[$frame_num,proof_completed]}" ]]; then
                local proof_started=$(printf "%.4f" ${frame_data[$frame_num,proof_started]})
                frame_outputs+=("Frame $frame_num: Started data shard proof at $proof_started (proof in progress)")
                ((count++))
            fi
        fi
    done
    output+=("Last Updated: $(date '+%Y-%m-%d %H:%M:%S')")
    if [ "$(is_app_finished_starting)" == "true" ]; then
        output+=("Peer ID: $(qtools peer-id)")
        output+=("Account: $(qtools account)")
        if $PRINT_QUIL; then
            output+=("Account Balance: $(qtools balance)")
        fi
    fi
    output+=("")
    if $PRINT_QUIL; then
        output+=("Legend: received->proof_started->proof_completed (total_duration, QUIL received in frame)")
    else
        output+=("Legend: received->proof_started->proof_completed (total_duration)")
    fi
    output+=("=======================")
    output+=("${frame_outputs[@]}")
    
    if [ $count -gt 0 ]; then
        proof_count=$(echo "$count - $no_proof_count" | bc)
        avg_duration=$(echo "scale=2; $total_duration / $proof_count" | bc)
        avg_started=$(echo "scale=2; $total_started / $proof_count" | bc)
        avg_completed=$(echo "scale=2; $total_completed / $proof_count" | bc)
        avg_evaluation_time=$(echo "scale=2; $total_evaluation_time / $proof_count" | bc)
        reward_landing_rate=$(echo "scale=2; $reward_total_count / $count" | bc)
        output+=("")
        output+=("$(figlet -f banner "Frame ${last_frame_num}")")
        output+=("Average received timestamp: $avg_started seconds")
        output+=("Average proof duration: $avg_duration seconds") 
        output+=("Average completed timestamp: $avg_completed seconds")
        output+=("Average evaluation time: $avg_evaluation_time seconds")
        output+=("")
        output+=("Total frames processed: $count (limit: $LIMIT)")
        
        
        if [ "$(is_app_finished_starting)" == "true" ]; then
            output+=("Total reward received: $reward_total QUIL")
            output+=("Reward landing rate: $reward_landing_rate (landed proofs/frame count)")

           
        fi

        output+=("")
        output+=("Last restart: $LAST_RESTART_TIMESTAMP")
        output+=("Current timestamp: $CURRENT_TIMESTAMP")
        output+=("Last frame received: $LAST_FRAME_RECEIVED_TIMESTAMP")
        output+=("")
        # Calculate time differences
        frame_age=$(echo "$CURRENT_TIMESTAMP - $LAST_FRAME_RECEIVED_TIMESTAMP" | bc)

        output+=("Current timestamp: $CURRENT_TIMESTAMP")
        output+=("Last Frame Received: $LAST_FRAME_RECEIVED_TIMESTAMP")
        output+=("Time since last frame: ${frame_age}s")

        if [ "$LAST_RESTART_TIMESTAMP" != "0" ]; then
            restart_age=$(echo "$CURRENT_TIMESTAMP - $LAST_RESTART_TIMESTAMP" | bc)
            output+=("Time since last restart: ${restart_age}s")
            output+=("Restart count: $RESTART_COUNT")
        fi

        if $PRINT_QUIL && [ "$(is_app_finished_starting)" == "true" ]; then
            avg_reward=$(echo "scale=6; $reward_total / $count" | bc)
            hourly_reward=$(get_hourly_reward $avg_reward $avg_started)
            daily_reward=$(get_daily_reward $avg_reward $avg_started)
            monthly_reward=$(get_monthly_reward $avg_reward $avg_started)
            output+=("")
            output+=("Average reward per frame: $avg_reward QUIL")
            output+=("Hourly reward: $hourly_reward QUIL")
            output+=("Daily reward: $daily_reward QUIL")
            output+=("Monthly reward: $monthly_reward QUIL")
        fi
    else
        output+=("No frames processed")
    fi
    output+=("=======================")
    output+=("Update interval: ${UPDATE_INTERVAL}s (use -u or --update to change)")
    if ! $ONE_SHOT; then
        clear
    fi
    figlet -f small "Frame Statistics"
    printf '%s\n' "${output[@]}"
}

# Function to process a single log line and record stats
process_log_line() {
    local line="$1"
    local log_type="$2"
    
    # Skip if line doesn't have ts property
    if ! echo "$line" | jq -e '.ts' >/dev/null 2>&1; then
        return
    fi

    LOG_TIMESTAMP=$(echo "$line" | jq -r '.ts' | awk '{printf "%.0f", $1}')

    if $DEBUG; then
        echo "LOG_TIMESTAMP: $LOG_TIMESTAMP"
    fi

    CURRENT_TIMESTAMP=$LOG_TIMESTAMP
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
        LAST_FRAME_RECEIVED_TIMESTAMP=$LOG_TIMESTAMP
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

check_for_auto_restart() {
    local line="$1"
    local CURRENT_LOG_TIMESTAMP=$(echo "$line" | jq -r '.ts' | awk '{printf "%.0f", $1}')

    if [ "$LAST_FRAME_RECEIVED_TIMESTAMP" != "0" ]; then
        # Check if we haven't received a proof in over 400 seconds
        local TIME_DIFF=$(echo "$CURRENT_LOG_TIMESTAMP - $LAST_FRAME_RECEIVED_TIMESTAMP" | bc -l)
        local RESTART_THRESHOLD=275
        local LAST_RESTART_THRESHOLD=$(($RESTART_THRESHOLD * ($RESTART_COUNT + 1)))
        
        local RESTART_AGE=$(echo "$CURRENT_LOG_TIMESTAMP - $LAST_RESTART_TIMESTAMP" | bc -l)

        if [ $(echo "$TIME_DIFF > $RESTART_THRESHOLD" | bc -l) -eq 1 ] && [ $RESTART_AGE -gt $LAST_RESTART_THRESHOLD ]; then
            
            echo "No proof received in over 250 seconds, restarting node..."
            echo "Current timestamp: $CURRENT_LOG_TIMESTAMP"
            echo "Last proof received: $LAST_FRAME_RECEIVED_TIMESTAMP"
            
            qtools restart
            LAST_RESTART_TIMESTAMP=$CURRENT_LOG_TIMESTAMP
            RESTART_COUNT=$(($RESTART_COUNT + 1))
        elif [ $RESTART_AGE -gt $LAST_RESTART_THRESHOLD ]; then
           RESTART_COUNT=0
           LAST_RESTART_TIMESTAMP=0
        fi
    fi
}

echo "Processing historical logs..."
# Process historical logs first until we reach LIMIT frames
while read -r line && [ ${#frame_numbers[@]} -lt $LIMIT ]; do
    process_log_line "$line" "historical"
done < <(journalctl -u $QUIL_SERVICE_NAME -r -o cat)

if $DEBUG; then
    echo "Frame numbers after processing historical logs: ${frame_numbers[@]}"
fi

display_stats

if $ONE_SHOT; then
    exit 0
fi

# Now follow new logs with periodic updates
last_update=$(date +%s)
while read -r line; do
    process_log_line "$line" "new"
    truncate_frame_records
    current_time=$(date +%s)
    if ((current_time - last_update >= UPDATE_INTERVAL)); then
        if [ "$AUTO_RESTART" == "true" ]; then
            check_for_auto_restart "$line"
        fi
        display_stats
        last_update=$current_time
    fi
done < <(journalctl -f -u $QUIL_SERVICE_NAME -o cat)
