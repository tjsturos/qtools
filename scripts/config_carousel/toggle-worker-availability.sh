#!/bin/bash

# Get publish multiaddr settings from config (reuse existing config)
SSH_KEY_PATH=$(yq eval '.settings.central_server.ssh_key_path' $QTOOLS_CONFIG_FILE)
REMOTE_USER=$(yq eval '.settings.central_server.remote_user' $QTOOLS_CONFIG_FILE)
REMOTE_HOST=$(yq eval '.settings.central_server.remote_host' $QTOOLS_CONFIG_FILE)
REMOTE_FILE="~/worker_availability.yml"

# Parse command line arguments
AVAILABILITY=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --available)
            AVAILABILITY="true"
            shift
            ;;
        --in-use)
            AVAILABILITY="false" 
            shift
            ;;
        *)
            echo "Invalid argument: $1"
            echo "Usage: $0 [--available|--in-use]"
            exit 1
            ;;
    esac
done

if [ -z "$AVAILABILITY" ]; then
    echo "Must specify either --available or --in-use"
    exit 1
fi

# Create or update the remote YAML file
ssh -i "$SSH_KEY_PATH" "${REMOTE_USER}@${REMOTE_HOST}" "
if [ ! -f $REMOTE_FILE ]; then
    echo 'available: $AVAILABILITY' > $REMOTE_FILE
    echo 'Worker availability set to $AVAILABILITY'
    exit 0
fi

yq eval -i '.available = $AVAILABILITY' $REMOTE_FILE
echo 'Worker availability set to $AVAILABILITY'
"


