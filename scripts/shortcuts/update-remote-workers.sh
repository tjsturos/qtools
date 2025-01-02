#!/bin/bash
CLUSTER_NAME="cluster1"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --cluster)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Get publish multiaddr settings from config
SSH_KEY_PATH=$(yq eval '.settings.publish_multiaddr.ssh_key_path' $QTOOLS_CONFIG_FILE)
REMOTE_USER=$(yq eval '.settings.publish_multiaddr.remote_user' $QTOOLS_CONFIG_FILE)
REMOTE_HOST=$(yq eval '.settings.publish_multiaddr.remote_host' $QTOOLS_CONFIG_FILE)
REMOTE_FILE=$(yq eval '.settings.publish_multiaddr.remote_file' $QTOOLS_CONFIG_FILE)

# Get remote workers for the specified cluster
REMOTE_WORKERS=$(ssh -i "$SSH_KEY_PATH" "${REMOTE_USER}@${REMOTE_HOST}" "yq eval '.$CLUSTER_NAME[]' $REMOTE_FILE")

if [ -z "$REMOTE_WORKERS" ]; then
    echo "No workers found in cluster $CLUSTER_NAME"
    exit 0
fi

# Get current workers from local config
CURRENT_WORKERS=$(yq eval '.engine.dataWorkerMultiaddrs[]' $QUIL_CONFIG_FILE)

# Add each remote worker if not already present
for REMOTE_WORKER in $REMOTE_WORKERS; do
    if ! echo "$CURRENT_WORKERS" | grep -q "$REMOTE_WORKER"; then
        echo "Adding worker $REMOTE_WORKER to local config"
        yq eval -i '.engine.dataWorkerMultiaddrs += ["'"$REMOTE_WORKER"'"]' $QUIL_CONFIG_FILE
    else
        echo "Worker $REMOTE_WORKER already exists in local config"
    fi
done

echo "Remote workers updated successfully"
