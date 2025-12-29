#!/bin/bash
# HELP: Starts the node application service. If .settings.debug is set to true or use --debug flag, this will start node in debug mode.
# PARAM: --debug: will start the node application in debug mode
# PARAM: --core <int>: start a specific worker/core by index
# PARAM: --master: start only the master service (not workers) - only available in clustering or manual mode
# Usage: qtools start
# Usage: qtools start --debug
# Usage: qtools start --core 5
# Usage: qtools start --master

# Source helper functions
source $QTOOLS_PATH/scripts/cluster/service-helpers.sh

# get settings
DEBUG_MODE="$(yq '.settings.debug' $QTOOLS_CONFIG_FILE)"
CORE_INDEX=""
MASTER_ONLY=false

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
        --master)
            MASTER_ONLY=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Backup peer config (skip if starting individual core or master only)
if [ -z "$CORE_INDEX" ] && [ "$MASTER_ONLY" != "true" ]; then
    if ! qtools backup-peer; then
        echo "Warning: Could not backup peer config, but continuing with node start"
    fi
fi

# Handle individual core start
if [ -n "$CORE_INDEX" ]; then
    if [ "$CORE_INDEX" == "0" ]; then
        echo -e "${RED}${ERROR_ICON} Core index 0 is reserved for master process. Use 'qtools start --master' to start master.${RESET}"
        exit 1
    fi
    # Only start individual core if manual mode is enabled
    if [ "$(is_manual_mode)" == "true" ]; then
        start_manual_worker "$CORE_INDEX"
    else
        echo -e "${RED}${ERROR_ICON} Cannot start individual core in automatic mode. Enable manual mode first with 'qtools manual-mode --enable'${RESET}"
        exit 1
    fi
    exit $?
fi

# Handle master-only start
if [ "$MASTER_ONLY" == "true" ]; then
    # --master flag only works in clustering or manual mode
    if [ "$(is_clustering_enabled)" != "true" ] && [ "$(is_manual_mode)" != "true" ]; then
        echo -e "${RED}✗ --master flag is only available in clustering or manual mode${RESET}"
        echo -e "${BLUE}${INFO_ICON} In automatic mode, starting the master service will also start workers automatically${RESET}"
        exit 1
    fi
    echo -e "${BLUE}${INFO_ICON} Starting master service only...${RESET}"
    start_master_service
    exit $?
fi

# Check if manual mode is enabled
if [ "$(is_manual_mode)" == "true" ]; then
    # Manual mode: start workers first, then master
    start_workers
    start_master_service
elif [ "$(is_clustering_enabled)" == "true" ]; then
    # Clustering mode: start master and workers as services
    start_master_service
    start_workers
else
    # Normal/automatic mode: only start master service (it will auto-spawn workers)
    start_master_service
fi

