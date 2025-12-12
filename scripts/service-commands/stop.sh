#!/bin/bash
# HELP: Stops the node application service. Will also clean up any leftover node processes (if any).
# PARAM: --core <int>: stop a specific worker/core by index
# PARAM: --kill: kill node processes forcefully
# PARAM: --wait: wait for next proof submission before stopping
# Usage: qtools stop
# Usage: qtools stop --core 5
# Usage: qtools stop --kill

# Source helper functions
source $QTOOLS_PATH/scripts/cluster/service-helpers.sh

# Initialize variables
IS_KILL_MODE=false
CORE_INDEX=""
WAIT=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --kill)
            IS_KILL_MODE=true
            shift
            ;;
        --core|--core-index)
            CORE_INDEX="$2"
            if [[ ! "$CORE_INDEX" =~ ^[0-9]+$ ]]; then
                echo "Error: --core requires a valid non-negative integer"
                exit 1
            fi
            shift 2
            ;;
        --wait)
            WAIT=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Handle individual core stop
if [ -n "$CORE_INDEX" ]; then
    if [ "$CORE_INDEX" == "0" ]; then
        echo -e "${RED}${ERROR_ICON} Core index 0 is reserved for master process. Use 'qtools stop' to stop master.${RESET}"
        exit 1
    fi
    stop_worker_by_core_index "$CORE_INDEX"
    exit $?
fi

# Handle wait flag for master service
if [ "$WAIT" == "true" ]; then
    echo -e "${BLUE}${INFO_ICON} Waiting for next proof submission or workers to be available...${RESET}"
    while read -r line; do
        if [[ $line =~ "submitting data proof" ]] || [[ $line =~ "workers not yet available for proving" ]]; then
            echo -e "${GREEN}${CHECK_ICON} Proof submission detected or workers not available, proceeding with stop${RESET}"
            break
        fi
    done < <(journalctl -u $QUIL_SERVICE_NAME -f -n 0)
fi

# Stop workers first, then master
stop_workers
stop_master_service

# Kill mode is essentially quick mode + kill the node process
if [ "$IS_KILL_MODE" == "true" ]; then
    echo "Kill mode, killing node process"
    pgrep -f node | grep -v $$ | xargs -r sudo kill -9
fi
