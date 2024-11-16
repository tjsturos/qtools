#!/bin/bash

# Array to store frame data
declare -A frame_data
frame_numbers=()

# Function to calculate and display statistics
display_stats() {
    echo "=== Frame Statistics ==="
    
    total_duration=0
    count=0
    
    for frame_num in "${frame_numbers[@]}"; do
        if [[ -n "${frame_data[$frame_num,received]}" && -n "${frame_data[$frame_num,proof_started]}" && -n "${frame_data[$frame_num,proof_completed]}" ]]; then
            duration=$(echo "${frame_data[$frame_num,proof_completed]} - ${frame_data[$frame_num,received]}" | bc)
            echo "Frame $frame_num:"
            echo "  Received at: ${frame_data[$frame_num,received]} seconds"
            echo "  Proof started at: ${frame_data[$frame_num,proof_started]} seconds" 
            echo "  Proof completed at: ${frame_data[$frame_num,proof_completed]} seconds"
            echo "  Total duration: $duration seconds"
            echo ""
            
            total_duration=$(echo "$total_duration + $duration" | bc)
            ((count++))
        fi
    done
    
    if [ $count -gt 0 ]; then
        avg_duration=$(echo "scale=2; $total_duration / $count" | bc)
        echo "Average proof duration: $avg_duration seconds"
        echo "Total frames processed: $count"
    fi
    echo "======================="
}

# Start monitoring logs
journalctl -f -o cat | while read -r line; do
    if [[ $line =~ "evaluating next frame" ]]; then
        frame_num=$(echo "$line" | jq -r '.frame_number')
        frame_age=$(echo "$line" | jq -r '.frame_age')
        
        frame_data[$frame_num,received]=$frame_age
        # Add to frame numbers array if not already present
        if [[ ! " ${frame_numbers[@]} " =~ " ${frame_num} " ]]; then
            frame_numbers+=($frame_num)
        fi
        
    elif [[ $line =~ "creating data shard ring proof" ]]; then
        frame_num=$(echo "$line" | jq -r '.frame_number')
        frame_age=$(echo "$line" | jq -r '.frame_age')
        frame_data[$frame_num,proof_started]=$frame_age
        
    elif [[ $line =~ "submitting data proof" ]]; then
        frame_num=$(echo "$line" | jq -r '.frame_number')
        frame_age=$(echo "$line" | jq -r '.frame_age')
        frame_data[$frame_num,proof_completed]=$frame_age
    fi
    
    # Display stats every 10 seconds
    if [[ ! -v LAST_DISPLAY ]] || [[ $(($(date +%s) - LAST_DISPLAY)) -ge 10 ]]; then
        display_stats
        LAST_DISPLAY=$(date +%s)
    fi
done
