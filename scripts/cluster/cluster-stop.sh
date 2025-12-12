#!/bin/bash

# Source helper functions
source $QTOOLS_PATH/scripts/cluster/service-helpers.sh

IS_MASTER=false
DRY_RUN=false
DATA_WORKER_COUNT=$(yq eval ".service.clustering.local_data_worker_count" $QTOOLS_CONFIG_FILE)

if [ "$DATA_WORKER_COUNT" == "null" ] || [ -z "$DATA_WORKER_COUNT" ]; then
    DATA_WORKER_COUNT=$(get_worker_count)
fi

echo -e "${BLUE}${INFO_ICON} Found configuration for $DATA_WORKER_COUNT data workers${RESET}"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --master)
            IS_MASTER=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Master node coordination
if [ "$IS_MASTER" == "true" ] || [ "$(is_master)" == "true" ]; then
    stop_master_service
    echo "Stopping services on remote servers..."
    ssh_command_to_each_server "qtools cluster-stop"
fi

# Stop local workers
stop_workers
