#!/bin/bash
# HELP: Monitors frame proofs and displays statistics.
# USAGE: ./monitor-frame-proofs.sh [OPTIONS]
# PARAM: --limit <number>: Limit the number of frames to process (optional) (default: 25)
# PARAM: --one-shot: Only process the last N lines of the log and exit (optional)
# PARAM: --debug: Print debug information (optional)
# PARAM: --no-quil: Don't display QUIL in the output (optional)
# PARAM: --update: Update interval in seconds (optional)
# PARAM: --auto-restart: Automatically restart the node if no frame is received in 275s * (N+1) where N is number of restarts in the last period (optional)
# PARAM: --display: Display individual frame lines in the output (optional)

# Array to store frame data
declare -A frame_data
frame_numbers=()

install_package figlet figlet false

ONE_SHOT=false
DEBUG=false
LIMIT=25
PRINT_QUIL=true
UPDATE_INTERVAL=25 # Default update interval in seconds
AUTO_RESTART=false
SHOW_FRAME_LINES=false
PUBLIC_RPC=""
# Parse command line args
while [[ $# -gt 0 ]]; do
  case $1 in
    -p|--public-rpc)
      PUBLIC_RPC="true"
      shift
      ;;
    -l|--limit)
      LIMIT="$2"
      shift 2
      ;;
    -o|--one-shot)
      ONE_SHOT=true
      shift
      ;;
    --debug)
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
    --display|-d)
      SHOW_FRAME_LINES=true
      shift
      ;;
    *)
      shift
      ;;
  esac
done

MAX_FRAME="$(yq eval '.engine.maxFrames // "-1"' $QUIL_CONFIG_FILE)"
# Check if local gRPC endpoint is configured and listening

if [ -n "$MAX_FRAME" ] && [ "$MAX_FRAME" -eq "$MAX_FRAME" ] 2>/dev/null && [ "$MAX_FRAME" -lt 1000 ] && [ "$MAX_FRAME" -ne -1 ] && [ -z "$PUBLIC_RPC" ]; then
    echo "Frame pruning is enabled, using the public RPC to get frame data"
    PUBLIC_RPC="true"
fi

GRPC_ADDR=$(yq eval '.listenGrpcMultiaddr' $QUIL_CONFIG_FILE)
if [ -n "$GRPC_ADDR" ] && [ -z "$PUBLIC_RPC" ]; then
    # Extract port from multiaddr (assumes format /ip4/127.0.0.1/tcp/PORT)
    PORT=$(echo $GRPC_ADDR | grep -oP '/tcp/\K[0-9]+')
    if [ -n "$PORT" ] && nc -z localhost $PORT 2>/dev/null; then
        echo "Using local gRPC endpoint listening on port $PORT"
    else
        echo "Local gRPC endpoint is not listening on port $PORT, using public RPC"
        PUBLIC_RPC="true"
    fi
else 
    if [ -z "$PUBLIC_RPC" ]; then
        echo "Local gRPC endpoint is not configured, using public RPC"
        PUBLIC_RPC="true"
    fi
fi

get_hourly_reward() {
    local avg_reward_per_second=$1
    if $DEBUG; then
        echo "Calculating hourly reward: $avg_reward_per_second * 3600"
    fi
    local reward=$(echo "scale=10; $avg_reward_per_second * 3600" | bc)
    echo $reward
}

get_daily_reward() {
    local avg_reward_per_second=$1
    if $DEBUG; then
        echo "Calculating daily reward: $avg_reward_per_second * 3600 * 24"
    fi
    local reward=$(echo "scale=10; $avg_reward_per_second * 3600 * 24" | bc)
    echo $reward
}

get_monthly_reward() {
    local avg_reward_per_second=$1
    if $DEBUG; then
        echo "Calculating monthly reward: $avg_reward_per_second * 3600 * 24 * 30"
    fi
    local reward=$(echo "scale=10; $avg_reward_per_second * 3600 * 24 * 30" | bc)
    echo $reward
}

CURRENT_TIMESTAMP=0
LAST_FRAME_RECEIVED_TIMESTAMP=0
LAST_RESTART_TIMESTAMP=0
RESTART_COUNT=0
FIRST_FRAME_RECEIVED_TIMESTAMP=0

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
        done < <(qclient token coins metadata ${PUBLIC_RPC:+--public-rpc} 2>/dev/null)
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
    
    # Sort frame numbers to calculate time between frames
    sorted_timestamps=()
    for frame_num in $(printf '%s\n' "${frame_numbers[@]}" | sort -n); do
        if [[ -n "${frame_data[$frame_num,received,timestamp]}" ]]; then
            sorted_timestamps+=(${frame_data[$frame_num,received,timestamp]})
        fi
    done

    # Calculate average time between frames
    total_time_between_frames=0
    frame_intervals=0
    for ((i=1; i<${#sorted_timestamps[@]}; i++)); do
        time_diff=$(echo "${sorted_timestamps[$i]} - ${sorted_timestamps[$i-1]}" | bc)
        total_time_between_frames=$(echo "$total_time_between_frames + $time_diff" | bc)
        ((frame_intervals++))
    done
    
    if [ $frame_intervals -gt 0 ]; then
        avg_time_between_frames=$(echo "scale=2; $total_time_between_frames / $frame_intervals" | bc)
    else
        avg_time_between_frames=0
    fi
    
    for frame_num in $(printf '%s\n' "${frame_numbers[@]}" | sort -n); do
        if [[ -n "${frame_data[$frame_num,received]}" && -n "${frame_data[$frame_num,proof_started]}" && -n "${frame_data[$frame_num,proof_completed]}" ]]; then
            local duration=$(printf "%.2f" $(echo "${frame_data[$frame_num,proof_completed]} - ${frame_data[$frame_num,received]}" | bc))
            local workers=${frame_data[$frame_num,proof_started,workers]}
            local ring=${frame_data[$frame_num,proof_completed,ring]}
            local received_timestamp=${frame_data[$frame_num,received,timestamp]}
            local received=$(printf "%.2f" ${frame_data[$frame_num,received]})
            local proof_started=$(printf "%.2f" ${frame_data[$frame_num,proof_started]})
            local proof_completed=$(printf "%.2f" ${frame_data[$frame_num,proof_completed]})
            local proof_completed_timestamp=${frame_data[$frame_num,proof_completed,timestamp]}
            local reward=$(printf "%.4f" ${frame_data[$frame_num,reward]})
            if [ "$reward" = "0.0000" ]; then
                reward=""
            fi

            if [ "$reward" != "" ]; then
                reward_total_count=$(echo "$reward_total_count + 1" | bc)
                reward_total=$(echo "$reward_total + $reward" | bc)
            fi

            last_frame_num=$frame_num
            if $SHOW_FRAME_LINES; then
                if $PRINT_QUIL; then
                    frame_outputs+=("$received_timestamp/$proof_completed_timestamp: Frame $frame_num ($ring:$workers): $received/$proof_started/$proof_completed (${duration}s${reward:+, $reward QUIL})")
                else
                    frame_outputs+=("$received_timestamp/$proof_completed_timestamp: Frame $frame_num ($ring:$workers): $received/$proof_started/$proof_completed (${duration}s)")
                fi
            fi
            
            total_duration=$(echo "$total_duration + $duration" | bc)
            total_started=$(echo "$total_started + $proof_started" | bc)
            total_completed=$(echo "$total_completed + $proof_completed" | bc)
            evaluation_time=$(echo "$proof_started - $received" | bc)
            total_evaluation_time=$(echo "$total_evaluation_time + $evaluation_time" | bc)
            
            ((count++))
        else
            ((no_proof_count++))
            local received_timestamp="${frame_data[$frame_num,received,timestamp]}"
            if [[ -n "${frame_data[$frame_num,received]}" && -z "${frame_data[$frame_num,proof_started]}" ]]; then
                local received=$(printf "%.4f" ${frame_data[$frame_num,received]})
                frame_outputs+=("$received_timestamp: Frame $frame_num: Recieved at $received (no proof started)")
                ((count++))
            elif [[ -n "${frame_data[$frame_num,proof_started]}" && -z "${frame_data[$frame_num,proof_completed]}" ]]; then
                local proof_started=$(printf "%.4f" ${frame_data[$frame_num,proof_started]})
                frame_outputs+=("$received_timestamp: Frame $frame_num: Started data shard proof at $proof_started (proof in progress)")
                ((count++))
            fi
        fi
    done
    output+=("Last Updated: $(date '+%Y-%m-%d %H:%M:%S')")
    output+=("Update interval: ${UPDATE_INTERVAL}s (use -u or --update to change)")
    output+=("")
    if [ "$(is_app_finished_starting)" == "true" ]; then
        output+=("Peer ID: $(qtools peer-id)")
        output+=("Account: $(qtools account)")
        if $PRINT_QUIL; then
            output+=("Account Balance: $(qtools balance)")
        fi
    fi
    output+=("")
    if $SHOW_FRAME_LINES; then
    if $PRINT_QUIL; then
        output+=("Legend: received->proof_started->proof_completed (total_duration, QUIL received in frame)")
        else
            output+=("Legend: received->proof_started->proof_completed (total_duration)")
        fi
        output+=("=======================")
        output+=("${frame_outputs[@]}")
    else 
        output+=("Hint: to see individual frame details, use --display to enable")
        output+=("=======================")
    fi
    
    if [ $count -gt 0 ]; then
        proof_count=$(echo "$count - $no_proof_count" | bc)
        avg_duration=$(echo "scale=2; $total_duration / $proof_count" | bc)
        avg_started=$(echo "scale=2; $total_started / $proof_count" | bc)
        avg_completed=$(echo "scale=2; $total_completed / $proof_count" | bc)
        avg_evaluation_time=$(echo "scale=2; $total_evaluation_time / $proof_count" | bc)
        reward_landing_rate=$(echo "scale=2; $reward_total_count / $count" | bc)
        output+=("")
        output+=("$(figlet -f banner "Frame ${last_frame_num}")")
        output+=("Total frames processed:           $count")
        output+=("")
        output+=("Average time between frames:      ${avg_time_between_frames}s")
        output+=("")
        output+=("Averages frame age (received / evaluation / proof duration / completed):")
        output+=("$avg_started / $avg_evaluation_time / $avg_duration / $avg_completed seconds")
        output+=("")

        if [ "$(is_app_finished_starting)" == "true" ]; then
            output+=("Total reward received:            $(printf "%.8f" $reward_total) QUIL")
            output+=("Reward landing rate:              $(printf "%.2f" $reward_landing_rate) (landed proofs/frame count)")
        fi

        output+=("")
        # Calculate time differences
        frame_age=$(echo "$CURRENT_TIMESTAMP - $LAST_FRAME_RECEIVED_TIMESTAMP" | bc)
        output+=("Current timestamp:                $CURRENT_TIMESTAMP")
        output+=("First frame received:             $FIRST_FRAME_RECEIVED_TIMESTAMP") 
        output+=("Last frame received:              $LAST_FRAME_RECEIVED_TIMESTAMP")
        output+=("Time since last frame:            ${frame_age}s")
        output+=("")
        local total_time=$(echo "$LAST_FRAME_RECEIVED_TIMESTAMP - $FIRST_FRAME_RECEIVED_TIMESTAMP" | bc)
        output+=("Time delta, last - first frame:   ${total_time}s")
        output+=("Total rewards for this period:    $(printf "%.8f" $reward_total) QUIL")

        if [ "$LAST_RESTART_TIMESTAMP" != "0" ]; then
            restart_age=$(echo "$CURRENT_TIMESTAMP - $LAST_RESTART_TIMESTAMP" | bc)
            output+=("Time since last restart:         ${restart_age}s")
            output+=("Restart count:                   $RESTART_COUNT")
        fi

        if $PRINT_QUIL && [ "$(is_app_finished_starting)" == "true" ]; then
            avg_reward=$(echo "scale=10; $reward_total / $reward_total_count" | bc)
            avg_reward_per_second=$(echo "scale=10; $reward_total / $total_time" | bc)
            hourly_reward=$(get_hourly_reward $avg_reward_per_second)
            daily_reward=$(get_daily_reward $avg_reward_per_second)
            monthly_reward=$(get_monthly_reward $avg_reward_per_second)

            output+=("Average reward per frame:         $(printf "%.8f" $avg_reward) QUIL")
            output+=("Average reward per second:        $(printf "%.8f" $avg_reward_per_second) QUIL")
            output+=("Hourly reward:                    $(printf "%.8f" $hourly_reward) QUIL")
            output+=("Daily reward:                     $(printf "%.8f" $daily_reward) QUIL")
            output+=("Monthly reward:                   $(printf "%.8f" $monthly_reward) QUIL")
        fi
    else
        output+=("No frames processed")
    fi
    output+=("=======================")
    
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

    if [[ "$CURRENT_TIMESTAMP" == "0" ]] || [[ "$LOG_TIMESTAMP" -gt "$CURRENT_TIMESTAMP" ]]; then
        CURRENT_TIMESTAMP=$LOG_TIMESTAMP
    fi

    if [[ "$FIRST_FRAME_RECEIVED_TIMESTAMP" == "0" ]] || [[ "$LOG_TIMESTAMP" -lt "$FIRST_FRAME_RECEIVED_TIMESTAMP" ]]; then
        FIRST_FRAME_RECEIVED_TIMESTAMP=$LOG_TIMESTAMP
    fi

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
        # Only update if this is a newer timestamp
        if [[ "$LAST_FRAME_RECEIVED_TIMESTAMP" == "0" ]] || [[ "$LOG_TIMESTAMP" -gt "$LAST_FRAME_RECEIVED_TIMESTAMP" ]]; then
            LAST_FRAME_RECEIVED_TIMESTAMP=$LOG_TIMESTAMP
        fi
        frame_age=$(echo "$line" | jq -r '.frame_age')
        if [[ "$log_type" != "historical" ]]; then
            echo "Received frame $frame_num (frame age $frame_age):"
        fi
        frame_data[$frame_num,received]=$frame_age
        frame_data[$frame_num,received,timestamp]=$LOG_TIMESTAMP
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
        if [[ $line =~ "dynamic" ]]; then
            workers=$(echo "$line" | jq -r '.active_workers')
            frame_data[$frame_num,proof_started,workers]=$workers
        fi
        
        frame_data[$frame_num,proof_completed]=$frame_age
        frame_data[$frame_num,proof_completed,ring]=$ring_size
        frame_data[$frame_num,proof_completed,timestamp]=$LOG_TIMESTAMP
        if [[ "$log_type" != "historical" ]]; then
            echo "Completed creating proof for frame $frame_num ($ring_size ring, frame age $frame_age):"
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
        # Set first frame timestamp to FIRST_FRAME_RECEIVED_TIMESTAMP
        if [ ${#sorted_frames[@]} -gt 0 ]; then
            first_frame=${sorted_frames[0]} 
            FIRST_FRAME_RECEIVED_TIMESTAMP=${frame_data[$first_frame,received,timestamp]}
        fi
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
