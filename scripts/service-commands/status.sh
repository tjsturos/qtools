#!/bin/bash
# HELP: Gets the node application service\'s current status.
# Usage: qtools status

WORKER_NUM=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --worker)
            shift
            WORKER_NUM="$1"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

if [ "$IS_CLUSTERING_ENABLED" == "true" ]; then
    if [ "$IS_MASTER" == "true" ]; then
        sudo systemctl status $QUIL_SERVICE_NAME.service --no-pager
    else
        if [ ! -z "$WORKER_NUM" ]; then
            sudo systemctl status "$QUIL_DATA_WORKER_SERVICE_NAME@$WORKER_NUM.service" --no-pager
        else
            echo "Is not the master, check status with --worker <int>"
        fi
    fi
else
    sudo systemctl status $QUIL_SERVICE_NAME.service --no-pager
fi

