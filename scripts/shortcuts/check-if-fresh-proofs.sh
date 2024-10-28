#!/bin/bash

# Parse command line arguments
DIFF="$(yq '.scheduled_tasks.check_if_fresh_proof_batches.default_diff // 1800' $QTOOLS_CONFIG_FILE)"  # Default value for diff
DRY_RUN=""
DEBUG=""

if [ -z "$QUIL_SERVICE_NAME" ]; then
    QUIL_SERVICE_NAME="ceremonyclient"
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --diff)
            DIFF="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --debug)
            DEBUG=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "Using diff: $DIFF seconds"
# Get logs from last $DIFF seconds
LOGS="$(journalctl -u $QUIL_SERVICE_NAME --no-hostname --output=cat --since "$DIFF seconds ago")"

if [ ! -z "$DEBUG" ]; then
    echo "Debug mode - showing logs:"
    echo "$LOGS"
fi


# Function to get the latest proof batch log
get_latest_proof_batch_log() {
    echo "$LOGS" | grep "publishing proof batch" | tail -n 1
}

get_latest_timestamp() {
    echo "$LOGS" | tail -n 1 | jq -r '.ts'
}

restart_application() {
    echo "Restarting the node..."
    qtools restart
}

if [ ! -z "$DEBUG" ]; then
    echo "get_latest_proof_batch_log: $(get_latest_proof_batch_log)"
    echo "get_latest_timestamp: $(get_latest_timestamp)"
fi

# Get the initial timestamp
lastest_proof_batch_timestamp=$(get_latest_proof_batch_log | jq -r '.ts')
current_timestamp=$(get_latest_timestamp | awk '{printf "%d", $1}')
increment=$(get_latest_proof_batch_log | jq -r '.increment')

if [ "$increment" == "0" ]; then
    echo "Reached the end of publishing proofs. Turning off fresh proof check..."
    if [ -z "$DRY_RUN" ]; then
        qtools toggle-fresh-proof-check --off
    fi
    exit 1
fi

if [ -z "$lastest_proof_batch_timestamp" ]; then
    echo "No proofs published timestamp found at all in latest logs. Restarting the node..."
    if [ -z "$DRY_RUN" ]; then
        restart_application
    fi
    exit 1
fi

# Get the current timestamp

lastest_proof_batch_timestamp=$(printf "%.0f" $lastest_proof_batch_timestamp)
current_timestamp=$(printf "%.0f" $current_timestamp)

echo "Lastest proof batch timestamp: $lastest_proof_batch_timestamp"
echo "Current timestamp: $current_timestamp"

# Calculate the time difference
time_diff=$((current_timestamp - lastest_proof_batch_timestamp))

echo "Time difference: $time_diff seconds"

# If the time difference is more than $DIFF, restart the node
if [ $time_diff -gt $DIFF ]; then
    echo "No new proofs published in the last $DIFF seconds. Restarting the node..."
    if [ -z "$DRY_RUN" ]; then
        restart_application
    fi
else
    echo "New proofs published ($increment) within the last $DIFF seconds. No action needed."
fi
