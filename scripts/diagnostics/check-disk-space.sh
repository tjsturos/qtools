#!/bin/bash

echo "Checking disk space..."

# Function to convert bytes to human-readable format
human_readable() {
    local bytes=$1
    if [[ $bytes -lt 1024 ]]; then
        echo "${bytes}B"
    elif [[ $bytes -lt 1048576 ]]; then
        echo "$(( (bytes + 512) / 1024 ))K"
    elif [[ $bytes -lt 1073741824 ]]; then
        echo "$(( (bytes + 524288) / 1048576 ))M"
    else
        echo "$(( (bytes + 536870912) / 1073741824 ))G"
    fi
}

# Get disk usage for root partition
root_usage=$(df -B1 / | awk 'NR==2 {print $3}')
root_available=$(df -B1 / | awk 'NR==2 {print $4}')
root_total=$(df -B1 / | awk 'NR==2 {print $2}')
root_percent=$(df -h / | awk 'NR==2 {print $5}')

echo "Root partition:"
echo "  Used: $(human_readable $root_usage)"
echo "  Available: $(human_readable $root_available)"
echo "  Total: $(human_readable $root_total)"
echo "  Usage: $root_percent"

# Check if /data partition exists and get its usage
if mountpoint -q /data; then
    data_usage=$(df -B1 /data | awk 'NR==2 {print $3}')
    data_available=$(df -B1 /data | awk 'NR==2 {print $4}')
    data_total=$(df -B1 /data | awk 'NR==2 {print $2}')
    data_percent=$(df -h /data | awk 'NR==2 {print $5}')

    echo "/data partition:"
    echo "  Used: $(human_readable $data_usage)"
    echo "  Available: $(human_readable $data_available)"
    echo "  Total: $(human_readable $data_total)"
    echo "  Usage: $data_percent"
else
    echo "/data partition not found"
    echo "ERROR: /data partition not found" >&2
fi

# Check for low disk space
threshold=90
if [[ ${root_percent%\%} -ge $threshold ]]; then
    echo "ERROR: Root partition usage is high (${root_percent})" >&2
fi

if mountpoint -q /data && [[ ${data_percent%\%} -ge $threshold ]]; then
    echo "ERROR: /data partition usage is high (${data_percent})" >&2
fi

echo "Disk space check completed."