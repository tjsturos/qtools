#!/bin/bash

# Function to get the start time from user input
get_start_time() {
    local start_time=""
    while [ -z "$start_time" ]; do
        read -p "Enter the start time (YYYY-MM-DDTHH:MM:SS format): " start_time
    done
    echo "$start_time"
}

# Get the start time from user input
START_TIME=$(get_start_time)
echo "Using start time: $START_TIME"

# Function to calculate average time difference
calculate_average() {
    local proof_batches=$1
    local total=0
    local count=0
    local prev_timestamp=""
    echo "Calculating average time between batches..."
    
    while IFS= read -r line; do
        timestamp=$(echo "$line" | jq -r '.ts')
        if [ -n "$prev_timestamp" ]; then
            time_diff=$(echo "$timestamp - $prev_timestamp" | bc)
            total=$(echo "$total + $time_diff" | bc)
            count=$((count + 1))
        fi
        prev_timestamp=$timestamp
    done <<< "$proof_batches"

    if [ $count -gt 0 ]; then
        average=$(echo "scale=3; $total / $count" | bc)
        echo "Average time between batches: $average seconds"
    else
        echo "No data found to calculate average"
    fi
}

# Run journalctl command and pipe output to calculate_average function
PROOF_BATCHES=$(journalctl -u $QUIL_SERVICE_NAME -f --no-hostname -g "publishing proof batch" --since $START_TIME --output=cat --no-pager)

calculate_average "$PROOF_BATCHES"
