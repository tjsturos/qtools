#!/bin/bash
# HELP: Kills worker processes by core index using SIGINT
# PARAM: <core_index>: Core index number (required)
# Usage: qtools kill-workers-by-core <core_index>
# Usage: qtools kill-workers-by-core 5

# Source helper functions if available
if [ -f "$QTOOLS_PATH/scripts/cluster/service-helpers.sh" ]; then
    source $QTOOLS_PATH/scripts/cluster/service-helpers.sh
fi

# Check if core index is provided
if [ -z "$1" ]; then
    echo "Error: Core index is required"
    echo "Usage: qtools kill-workers-by-core <core_index>"
    exit 1
fi

CORE_INDEX="$1"

# Validate core index is a number
if [[ ! "$CORE_INDEX" =~ ^[0-9]+$ ]]; then
    echo "Error: Core index must be a valid non-negative integer"
    exit 1
fi

# Find all PIDs matching the core index
# Use pgrep to find processes with core=<core_index> in command line
pids=$(pgrep -f "core=${CORE_INDEX}" 2>/dev/null)

if [ -z "$pids" ]; then
    echo "No worker processes found for core index $CORE_INDEX"
    exit 1
fi

# Kill each process with SIGINT
echo "Killing worker processes for core index $CORE_INDEX..."
for pid in $pids; do
    if sudo kill -0 "$pid" 2>/dev/null; then
        echo "Sending SIGINT to PID $pid"
        sudo kill -SIGINT "$pid"
    fi
done

echo "Done. Sent SIGINT to all worker processes for core index $CORE_INDEX"
