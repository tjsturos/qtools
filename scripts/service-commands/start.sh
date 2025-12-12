#!/bin/bash
# HELP: Starts the node application service. If .settings.debug is set to true or use --debug flag, this will start node in debug mode.
# PARAM: --debug: will start the node application in debug mode
# PARAM: --core <int>: start a specific worker/core by index
# Usage: qtools start
# Usage: qtools start --debug
# Usage: qtools start --core 5

# Source helper functions
source $QTOOLS_PATH/scripts/cluster/service-helpers.sh

# get settings
DEBUG_MODE="$(yq '.settings.debug' $QTOOLS_CONFIG_FILE)"
CORE_INDEX=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            DEBUG_MODE="true"
            shift
            ;;
        --core)
            CORE_INDEX="$2"
            if [[ ! "$CORE_INDEX" =~ ^[0-9]+$ ]]; then
                echo "Error: --core requires a valid non-negative integer"
                exit 1
            fi
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Backup peer config (skip if starting individual core)
if [ -z "$CORE_INDEX" ]; then
    if ! qtools backup-peer; then
        echo "Warning: Could not backup peer config, but continuing with node start"
    fi
fi

# Handle individual core start
if [ -n "$CORE_INDEX" ]; then
    if [ "$CORE_INDEX" == "0" ]; then
        echo -e "${RED}${ERROR_ICON} Core index 0 is reserved for master process${RESET}"
        exit 1
    fi
    start_worker_by_core_index "$CORE_INDEX"
    exit $?
fi

# Start master and all workers
start_master_service
start_workers

