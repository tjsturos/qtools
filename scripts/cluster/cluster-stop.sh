#! /bin/bash

IS_MASTER=false
DRY_RUN=false

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

if [ "$IS_MASTER" == "true" ] || [ "$(is_master)" == "true" ]; then
    stop_master_service
    echo "Stopping services on remote servers..."
    ssh_command_to_each_server "qtools stop-cluster"
fi

CORE_START_INDEX=1
DATA_WORKER_COUNT="$(yq eval '.service.clustering.local_dataworker_count' $QTOOLS_CONFIG_FILE)"
END_CORE_INDEX=$((CORE_START_INDEX + DATA_WORKER_COUNT - 1))
stop_local_data_worker_services $CORE_START_INDEX $END_CORE_INDEX


