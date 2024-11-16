#!/bin/bash

# Array to store frame data
declare -A frame_data
frame_numbers=()

# Start monitoring logs
# Default number of lines to process
LINES=1000
ONE_SHOT=false

# Parse command line args
while [[ $# -gt 0 ]]; do
  case $1 in
    -n|--lines)
      LINES="$2"
      shift 2
      ;;
    -o|--one-shot)
      ONE_SHOT=true
      shift
      ;;
    *)
      shift
      ;;
  esac
done


# Function to calculate and display statistics
display_stats() {
    if ! $ONE_SHOT; then
        clear
    else
        echo "Frame numbers: ${frame_numbers[@]}"
    fi
    echo "=== Frame Statistics === ($(date '+%Y-%m-%d %H:%M:%S'))"
    
    total_duration=0
    count=0
    
    for frame_num in "${frame_numbers[@]}"; do
        if [[ -n "${frame_data[$frame_num,received]}" && -n "${frame_data[$frame_num,proof_started]}" && -n "${frame_data[$frame_num,proof_completed]}" ]]; then
            duration=$(echo "${frame_data[$frame_num,proof_completed]} - ${frame_data[$frame_num,received]}" | bc)
            local workers=${frame_data[$frame_num,proof_started,workers]}
            local ring=${frame_data[$frame_num,proof_completed,ring]}
            local received=${frame_data[$frame_num,received]}
            local proof_started=${frame_data[$frame_num,proof_started]}
            local proof_completed=${frame_data[$frame_num,proof_completed]}

            echo "Frame $frame_num ($workers workers, ring $ring): $received -> $proof_started -> $proof_completed ($duration seconds)"
            
            total_duration=$(echo "$total_duration + $duration" | bc)
            ((count++))
        fi
    done
    
    if [ $count -gt 0 ]; then
        avg_duration=$(echo "scale=2; $total_duration / $count" | bc)
        echo ""
        echo "Average proof duration: $avg_duration seconds"
        echo "Total frames processed: $count"
    fi
    echo "======================="
}

# Function to process a single log line and record stats
process_log_line() {
    local line="$1"

    # Extract frame number first and validate
    frame_num=$(echo "$line" | jq -r '.frame_number')
    if [[ -z "$frame_num" || "$frame_num" == "null" ]]; then
        return
    fi

    if [[ $line =~ "evaluating next frame" ]]; then
        frame_age=$(echo "$line" | jq -r '.frame_age')
        echo "Received frame $frame_num (frame age $frame_age):"
        
        frame_data[$frame_num,received]=$frame_age
        # Add to frame numbers array if not already present
        if [[ ! " ${frame_numbers[@]} " =~ " ${frame_num} " ]]; then
            frame_numbers+=($frame_num)
        fi
        
    elif [[ $line =~ "creating data shard ring proof" ]]; then
        frame_age=$(echo "$line" | jq -r '.frame_age')
        workers=$(echo "$line" | jq -r '.active_workers')
        echo "Started creating proof for frame $frame_num ($workers workers, frame age $frame_age):"
        frame_data[$frame_num,proof_started]=$frame_age
        frame_data[$frame_num,proof_started,workers]=$workers
        
    elif [[ $line =~ "submitting data proof" ]]; then
        frame_age=$(echo "$line" | jq -r '.frame_age')
        ring_size=$(echo "$line" | jq -r '.ring')
        echo "Completed creating proof for frame $frame_num ($ring_size ring, frame age $frame_age):"
        frame_data[$frame_num,proof_completed]=$frame_age
        frame_data[$frame_num,proof_completed,ring]=$ring_size
    fi
}

echo "Processing historical logs (last $LINES lines)..."
# Process historical logs first
journalctl -u $QUIL_SERVICE_NAME -r -n "$LINES" -o cat | while read -r line; do
    process_log_line "$line"
done

# Display initial stats

display_stats

if $ONE_SHOT; then
    exit 0
fi

# Now follow new logs
journalctl -f -u $QUIL_SERVICE_NAME -o cat | while read -r line; do
    process_log_line "$line"
    
    # Display stats every 10 seconds
    if [[ ! -v LAST_DISPLAY ]] || [[ $(($(date +%s) - LAST_DISPLAY)) -ge 10 ]]; then
        display_stats
        LAST_DISPLAY=$(date +%s)
    fi
done
