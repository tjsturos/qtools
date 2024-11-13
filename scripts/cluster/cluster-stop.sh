#! /bin/bash

IS_MASTER=false
DRY_RUN=false
MAX_CORES=$(nproc)
DATA_WORKER_COUNT=$(yq eval ".service.clustering.local_data_worker_count" $QTOOLS_CONFIG_FILE)

if [ "$DATA_WORKER_COUNT" == "null" ]; then
    DATA_WORKER_COUNT=$MAX_CORES
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

# Function to clean up processes
clean_up_process() {
    if [ "$IS_QUICK_MODE" != "true" ]; then
        # Backup store
        qtools backup-store

        # Disable backups
        qtools toggle-backups --off
        
        # Disable diagnostics
        qtools toggle-diagnostics --off

        # Disable statistics
        qtools toggle-statistics --off

        qtools update-cron
    else
        echo "Skipping process cleanup in quick mode."
    fi
}

if [ "$IS_MASTER" == "true" ] || [ "$(is_master)" == "true" ]; then
    sudo systemctl stop $MASTER_SERVICE_NAME
    echo "Stopping services on remote servers..."
    ssh_command_to_each_server "qtools cluster-stop"
    clean_up_process
fi

stop_local_data_worker_services 1 $DATA_WORKER_COUNT
