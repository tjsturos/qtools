#!/bin/bash
# HELP: Gets the worker count from node-info. Default prints both running and active workers. Use --active or --running to print only one.
# PARAM: --active: Print only the active workers count
# PARAM: --running: Print only the running workers count
# Usage: qtools worker-count
# Usage: qtools worker-count --active
# Usage: qtools worker-count --running

# Parse command line arguments
SHOW_ACTIVE_ONLY=false
SHOW_RUNNING_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --active)
            SHOW_ACTIVE_ONLY=true
            shift
            ;;
        --running)
            SHOW_RUNNING_ONLY=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--active|--running]"
            exit 1
            ;;
    esac
done

# Get node-info output
OUTPUT="$(run_node_command --node-info --signature-check=false "$@" 2>/dev/null)"

# Extract worker counts
RUNNING_WORKERS=$(echo "$OUTPUT" | grep -E "^Running Workers:" | awk '{print $3}')
ACTIVE_WORKERS=$(echo "$OUTPUT" | grep -E "^Active Workers:" | awk '{print $3}')

# Validate that we got the data
if [ -z "$RUNNING_WORKERS" ] || [ -z "$ACTIVE_WORKERS" ]; then
    echo "Error: Could not extract worker counts from node-info output" >&2
    exit 1
fi

# Print based on flags
if [ "$SHOW_ACTIVE_ONLY" == "true" ]; then
    echo "$ACTIVE_WORKERS"
elif [ "$SHOW_RUNNING_ONLY" == "true" ]; then
    echo "$RUNNING_WORKERS"
else
    # Default: print both
    echo "Running Workers: $RUNNING_WORKERS"
    echo "Active Workers: $ACTIVE_WORKERS"
fi
