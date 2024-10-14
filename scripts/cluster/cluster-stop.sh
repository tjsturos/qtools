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
    sudo systemctl stop $MASTER_SERVICE_NAME
    echo "Stopping services on remote servers..."
    ssh_command_to_each_server "qtools cluster-stop"
fi

stop_local_data_worker_services 1 $DATA_WORKER_COUNT
