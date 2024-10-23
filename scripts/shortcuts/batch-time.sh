#!/bin/bash

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
journalctl -u ceremonyclient.service -f --no-hostname -g "publishing proof batch" --since "2024-10-23T01:09:00.468198+00:00" | calculate_average
