#!/bin/bash

# Get publish multiaddr settings from config (reuse existing config)
SSH_KEY_PATH=$(yq eval '.settings.central_server.ssh_key_path' $QTOOLS_CONFIG_FILE)
REMOTE_USER=$(yq eval '.settings.central_server.remote_user' $QTOOLS_CONFIG_FILE)
REMOTE_HOST=$(yq eval '.settings.central_server.remote_host' $QTOOLS_CONFIG_FILE)
REMOTE_FILE="~/worker_availability.yml"


check_availability() {
    # Check availability status
    AVAILABLE=$(ssh -i "$SSH_KEY_PATH" "${REMOTE_USER}@${REMOTE_HOST}" "
    if [ ! -f $REMOTE_FILE ]; then
        echo 'true'
        exit 0
    fi

    yq eval '.available' $REMOTE_FILE
    ")
    echo $AVAILABLE
}

if [[ "$AVAILABLE" == "true" ]]; then
    echo "Workers are available"
    sudo systemctl start $QUIL_SERVICE_NAME
else
    echo "Workers are not available"
    sudo systemctl stop $QUIL_SERVICE_NAME
fi
