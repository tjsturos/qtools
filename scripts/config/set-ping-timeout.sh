#!/bin/bash
# HELP: Sets the ping timeout value in the node config
# PARAM: <int>: timeout value in seconds, or "default" to reset to 0
# Usage: qtools set-ping-timeout <int>
# Usage: qtools set-ping-timeout default

if [ $# -ne 1 ]; then
    echo "Usage: qtools set-ping-timeout <int>"
    echo "       qtools set-ping-timeout default"
    exit 1
fi

if [ "$1" == "default" ]; then
    yq -i 'del(.p2p.pingTimeout)' $QUIL_CONFIG_FILE
    echo "Ping timeout reset to default"
else
    if ! [[ "$1" =~ ^[0-9]+$ ]]; then
        echo "Error: Timeout value must be a positive integer"
        exit 1
    fi
    yq -i ".p2p.pingTimeout = \"$1s\"" $QUIL_CONFIG_FILE
    echo "Ping timeout set to $1s"
fi

qtools restart
