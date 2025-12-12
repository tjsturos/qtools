#!/bin/bash
# HELP: Sets the sync timeout value in the node config
# PARAM: <int>: timeout value in seconds, or "default" to reset to 0
# Usage: qtools set-sync-timeout <int>
# Usage: qtools set-sync-timeout default

if [ $# -ne 1 ]; then
    echo "Usage: qtools set-sync-timeout <int>"
    echo "       qtools set-sync-timeout default"
    exit 1
fi

if [ "$1" == "default" ]; then
    yq -i 'del(.engine.syncTimeout)' $QUIL_CONFIG_FILE
    echo "Sync timeout reset to default"
else
    if ! [[ "$1" =~ ^[0-9]+$ ]]; then
        echo "Error: Timeout value must be a positive integer"
        exit 1
    fi
    yq -i ".engine.syncTimeout = \"$1s\"" $QUIL_CONFIG_FILE
    echo "Sync timeout set to $1s"
fi

qtools restart
