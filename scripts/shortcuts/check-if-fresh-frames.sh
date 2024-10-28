#!/bin/bash

# Parse command line arguments
DIFF="$(yq '.scheduled_tasks.check_if_fresh_frames.default_diff // 1800' $QTOOLS_CONFIG_FILE)"  # Default value for diff

if [ -z "$QUIL_SERVICE_NAME" ]; then
    QUIL_SERVICE_NAME="ceremonyclient"
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --diff)
            DIFF="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "Using diff: $DIFF seconds"


get_latest_frame_received_log() {
    journalctl -u $QUIL_SERVICE_NAME --no-hostname -g "received new leading frame" --output=cat -r -n 1
}

get_latest_timestamp() {
    journalctl -u $QUIL_SERVICE_NAME --no-hostname --output=cat -r -n 1 | jq -r '.ts'
}

restart_application() {
    echo "Restarting the node..."
    qtools restart
}

# Get the initial timestamp
last_timestamp=$(get_latest_frame_received_log | jq -r '.ts' )

if [ -z "$last_timestamp" ]; then
    echo "No frames recieved timestamp found at all in latest logs. Restarting the node..."
    restart_application
    exit 1
fi

last_timestamp=$(echo $last_timestamp | awk '{print int($1)}')
# Get the current timestamp
current_timestamp=$(get_latest_timestamp | awk '{print int($1)}')

echo "Last timestamp: $last_timestamp"
echo "Current timestamp: $current_timestamp"

# Calculate the time difference
time_diff=$(echo "$current_timestamp - $last_timestamp" | bc)

echo "Time difference: $time_diff seconds"

# If the time difference is more than $DIFF, restart the node
if [ $time_diff -gt $DIFF ]; then
    echo "No new proofs submitted in the last $DIFF seconds. Restarting the node..."
    restart_application
else
    echo "New proofs submitted within the last $DIFF seconds. No action needed."
fi
