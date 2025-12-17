#!/bin/bash
# HELP: Gets the PIDs for the service master and cores.
# PARAM: --worker <int> - Worker number (0 for master/default, or specific worker number)
# PARAM: --core <int> - Core number (searches for processes with core=<int>)
# Usage: qtools get-pid
# Usage: qtools get-pid --worker 0
# Usage: qtools get-pid --worker 1
# Usage: qtools get-pid --core 1

WORKER_NUM=""
USE_CORE_FLAG=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --worker|--core)
            if [ "$1" == "--core" ]; then
                USE_CORE_FLAG=true
            fi
            shift
            WORKER_NUM="$1"
            if [[ ! "$WORKER_NUM" =~ ^[0-9]+$ ]]; then
                echo "Error: $1 requires a valid non-negative integer"
                exit 1
            fi
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: qtools get-pid [--worker <int>|--core <int>]"
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
    local use_core_flag=$2
    local pid=""

    if [ "$use_core_flag" == "true" ]; then
        # Search for processes with core=<worker_num> (skip binary name check)
        # Try pgrep first (more reliable)
        if command -v pgrep >/dev/null 2>&1; then
            # pgrep -f searches full command line
            pid=$(pgrep -f "core=${worker_num}" | head -n 1)
        fi

        # Fallback to ps + grep if pgrep didn't work or found nothing
        if [ -z "$pid" ]; then
            pid=$(ps aux | grep -E "core=${worker_num}" | grep -v grep | awk '{print $2}' | head -n 1)
        fi
    else
        # Search for processes matching the binary with --core <worker_num>
        local binary_name=$(basename "$LINKED_NODE_BINARY")
        # Try pgrep first (more reliable)
        if command -v pgrep >/dev/null 2>&1; then
            # pgrep -f searches full command line
            pid=$(pgrep -f "${binary_name}.*--core ${worker_num}" | head -n 1)
        fi

        # Fallback to ps + grep if pgrep didn't work or found nothing
        if [ -z "$pid" ]; then
            pid=$(ps aux | grep -E "${binary_name}.*--core ${worker_num}" | grep -v grep | awk '{print $2}' | head -n 1)
        fi
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
        # Get worker PID by grepping for process with --core <worker_num> or core=<worker_num>
        PID=$(get_worker_pid_from_process "$WORKER_NUM" "$USE_CORE_FLAG")
        if [ -z "$PID" ]; then
            if [ "$USE_CORE_FLAG" == "true" ]; then
                echo "Core $WORKER_NUM process is not running"
            else
                echo "Worker $WORKER_NUM process is not running"
            fi
            exit 1
        else
            echo "$PID"
        fi
    fi
fi
