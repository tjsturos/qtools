
enable_local_data_worker_services 1 $DATA_WORKER_COUNT

if [ "$(is_master)" == "true" ]; then
    sudo systemctl enable $MASTER_SERVICE_NAME
    ssh_command_to_each_server "qtools cluster-enable"
fi