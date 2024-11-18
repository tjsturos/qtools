#!/bin/bash

# Array to store frame data
declare -A frame_data
frame_numbers=()

# Start monitoring logs
# Default number of lines to process
LINES=1000
ONE_SHOT=false
DEBUG=false

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
    -d|--debug)
      DEBUG=true
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
    fi

    if $DEBUG; then
        echo "Frame numbers: ${frame_numbers[@]}"
    fi

    echo "=== Frame Statistics === ($(date '+%Y-%m-%d %H:%M:%S'))"
    
    total_duration=0
    count=0
    
    for frame_num in $(printf '%s\n' "${frame_numbers[@]}" | sort -n); do
        if [[ -n "${frame_data[$frame_num,received]}" && -n "${frame_data[$frame_num,proof_started]}" && -n "${frame_data[$frame_num,proof_completed]}" ]]; then
            local duration=$(printf "%.4f" $(echo "${frame_data[$frame_num,proof_completed]} - ${frame_data[$frame_num,received]}" | bc))
            local workers=${frame_data[$frame_num,proof_started,workers]}
            local ring=${frame_data[$frame_num,proof_completed,ring]}
            local received=$(printf "%.4f" ${frame_data[$frame_num,received]})
            local proof_started=$(printf "%.4f" ${frame_data[$frame_num,proof_started]})
            local proof_completed=$(printf "%.4f" ${frame_data[$frame_num,proof_completed]})

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
done < <(journalctl -f -u $QUIL_SERVICE_NAME -o cat)
