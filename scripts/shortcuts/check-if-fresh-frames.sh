#!/bin/bash

# Parse command line arguments
DIFF=120  # Default value for diff

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

# Validate that DIFF and CYCLE are positive integers
if ! [[ "$DIFF" =~ ^[0-9]+$ ]] || ! [[ "$CYCLE" =~ ^[0-9]+$ ]]; then
    echo "Error: --diff and --cycle must be positive integers"
    exit 1
fi

echo "Using diff: $DIFF seconds"
echo "Using cycle: $CYCLE seconds"


# Function to get the latest timestamp
get_latest_frame_received_timestamp() {
    journalctl -u $QUIL_SERVICE_NAME --no-hostname -g "received new leading frame" --output=json -n 1 | jq -r '.ts'
}

get_latest_timestamp() {
    journalctl -u $QUIL_SERVICE_NAME --no-hostname --output=json -n 1 | jq -r '.ts'
}

# Get the initial timestamp
last_timestamp=$(get_latest_frame_received_timestamp)

# Get the current timestamp
current_timestamp=$(get_latest_timestamp)

echo "Last timestamp: $last_timestamp"
echo "Current timestamp: $current_timestamp"

# Calculate the time difference
time_diff=$(( $(date -d "$current_timestamp" +%s) - $(date -d "$last_timestamp" +%s) ))

echo "Time difference: $time_diff seconds"

# If the time difference is more than 2 minutes (120 seconds)
if [ $time_diff -gt $DIFF ]; then
    echo "No new leading frame received in the last $DIFF seconds. Restarting the node..."
    qtools restart
    # Update the last timestamp after restart
    last_timestamp=$(get_latest_timestamp)
else
    echo "New leading frame received within the last $DIFF seconds. No action needed."
    last_timestamp=$current_timestamp
fi

