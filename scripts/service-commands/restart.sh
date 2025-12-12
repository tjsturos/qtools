#!/bin/bash

# HELP: Stops and then starts the node application service, effectively a restart.
# PARAM: --core <int>: restart a specific worker/core by index
# PARAM: --wait: wait for next proof submission before restarting
# Usage: qtools restart
# Usage: qtools restart --core 5
# Usage: qtools restart --wait

# Source helper functions
source $QTOOLS_PATH/scripts/cluster/service-helpers.sh

WAIT=false
CORE_INDEX=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --on-next-proof|--wait|on-next-submission|-w|-np)
            WAIT=true
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

# Handle individual core restart
if [ -n "$CORE_INDEX" ]; then
    if [ "$CORE_INDEX" == "0" ]; then
        echo -e "${RED}${ERROR_ICON} Core index 0 is reserved for master process. Use 'qtools restart' to restart master.${RESET}"
        exit 1
    fi
    stop_worker_by_core_index "$CORE_INDEX"
    sleep 1
    start_worker_by_core_index "$CORE_INDEX"
    exit $?
fi

# Handle wait flag
if [ "$WAIT" == "true" ]; then
    echo -e "${BLUE}${INFO_ICON} Waiting for next proof submission or workers to be available...${RESET}"
    while read -r line; do
        if [[ $line =~ "submitting data proof" ]] || [[ $line =~ "workers not yet available for proving" ]]; then
            echo -e "${GREEN}${CHECK_ICON} Proof submission detected or workers not available, proceeding with restart${RESET}"
            break
        fi
    done < <(journalctl -u $QUIL_SERVICE_NAME -f -n 0)
fi

# Restart master and workers
if [ "$(is_clustering_enabled)" == "true" ]; then
    if [ "$(is_master)" == "true" ]; then
        sudo systemctl restart $QUIL_SERVICE_NAME
        restart_cluster_data_workers
        wait
    else
        qtools refresh-data-workers
        wait
    fi
else
    sudo systemctl restart $QUIL_SERVICE_NAME
fi