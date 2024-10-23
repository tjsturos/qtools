#!/bin/bash

# Function to get the start time from user input
get_start_time() {
    local start_time=""
    while [ -z "$start_time" ]; do
        read -p "Enter the start time (YYYY-MM-DDTHH:MM:SS format): " start_time
        if ! date -d "$start_time" >/dev/null 2>&1; then
            echo "Invalid date format. Please use YYYY-MM-DDTHH:MM:SS format."
            start_time=""
        fi
    done
    echo "$start_time"
}

# Get the start time from user input
START_TIME=$(get_start_time)

# Update the journalctl command with the user-provided start time
JOURNALCTL_CMD="journalctl -u $QUIL_SERVICE_NAME -f --no-hostname -g \"publishing proof batch\" --since \"$START_TIME\""

echo "Using start time: $START_TIME"
echo "Journalctl command: $JOURNALCTL_CMD"


# Function to calculate average time difference
calculate_average() {
    local total=0
    local count=0
    local prev_timestamp=""

    while IFS= read -r line; do
        timestamp=$(echo "$line" | awk '{print $1}')
        if [ -n "$prev_timestamp" ]; then
            diff=$(date -d "$timestamp" +%s.%N)
            prev=$(date -d "$prev_timestamp" +%s.%N)
            time_diff=$(echo "$diff - $prev" | bc)
            total=$(echo "$total + $time_diff" | bc)
            count=$((count + 1))
        fi
        prev_timestamp=$timestamp
    done

    if [ $count -gt 0 ]; then
        average=$(echo "scale=3; $total / $count" | bc)
        echo "Average time between batches: $average seconds"
    else
        echo "No data found to calculate average"
    fi
}

# Run journalctl command and pipe output to calculate_average function
$JOURNALCTL_CMD | calculate_average
