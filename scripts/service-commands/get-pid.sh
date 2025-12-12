#!/bin/bash
# HELP: Gets the PIDs for the service master and cores.
# PARAM: --worker <int> - Worker number (0 for master/default, or specific worker number)
# Usage: qtools get-pid
# Usage: qtools get-pid --worker 0
# Usage: qtools get-pid --worker 1

WORKER_NUM=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --worker)
            shift
            WORKER_NUM="$1"
            if [[ ! "$WORKER_NUM" =~ ^[0-9]+$ ]]; then
                echo "Error: --worker requires a valid non-negative integer"
                exit 1
            fi
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: qtools get-pid [--worker <int>]"
            exit 1
            ;;
    esac
done

# Default to worker 0 (master) if not specified
if [ -z "$WORKER_NUM" ]; then
    WORKER_NUM="0"
fi

get_pid() {
    local service_name=$1
    local pid=$(sudo systemctl show -p MainPID --value "$service_name" 2>/dev/null)
    if [ -z "$pid" ] || [ "$pid" == "0" ]; then
        echo ""
    else
        echo "$pid"
    fi
}

get_worker_pid_from_process() {
    local worker_num=$1
    local binary_name=$(basename "$LINKED_NODE_BINARY")
    # Grep for processes matching the binary with --core <worker_num>
    # Use pgrep to find PIDs, or ps + grep as fallback
    local pid=""

    # Try pgrep first (more reliable)
    if command -v pgrep >/dev/null 2>&1; then
        # pgrep -f searches full command line
        pid=$(pgrep -f "${binary_name}.*--core ${worker_num}" | head -n 1)
    fi

    # Fallback to ps + grep if pgrep didn't work or found nothing
    if [ -z "$pid" ]; then
        pid=$(ps aux | grep -E "${binary_name}.*--core ${worker_num}" | grep -v grep | awk '{print $2}' | head -n 1)
    fi

    echo "$pid"
}

if [ "$IS_CLUSTERING_ENABLED" == "true" ]; then
    # Clustering mode (local or full) - workers are systemd services
    if [ "$WORKER_NUM" == "0" ]; then
        # Get master PID
        if [ "$IS_MASTER" == "true" ]; then
            PID=$(get_pid "$QUIL_SERVICE_NAME.service")
            if [ -z "$PID" ]; then
                echo "Master service is not running"
                exit 1
            else
                echo "$PID"
            fi
        else
            echo "Error: Worker 0 (master) is not available on this node. Use --worker <int> to specify a worker number."
            exit 1
        fi
    else
        # Get worker PID from systemd service
        PID=$(get_pid "$QUIL_DATA_WORKER_SERVICE_NAME@$WORKER_NUM.service")
        if [ -z "$PID" ]; then
            echo "Worker $WORKER_NUM service is not running"
            exit 1
        else
            echo "$PID"
        fi
    fi
else
    # Automatic mode - master spawns workers as processes
    if [ "$WORKER_NUM" == "0" ]; then
        # Get master PID
        PID=$(get_pid "$QUIL_SERVICE_NAME.service")
        if [ -z "$PID" ]; then
            echo "Service is not running"
            exit 1
        else
            echo "$PID"
        fi
    else
        # Get worker PID by grepping for process with --core <worker_num>
        PID=$(get_worker_pid_from_process "$WORKER_NUM")
        if [ -z "$PID" ]; then
            echo "Worker $WORKER_NUM process is not running"
            exit 1
        else
            echo "$PID"
        fi
    fi
fi
