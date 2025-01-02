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

# Get the list of remote workers from the config
REMOTE_WORKERS=$(yq eval '.engine.dataWorkerMultiaddrs' $QUIL_CONFIG_FILE)
REMOTE_FILE=~/cluster.yml

publish_multiaddr() {
    MULTIADDR=$1
    # Create or update the remote YAML file
    ssh -i "$SSH_KEY_PATH" "${REMOTE_USER}@${REMOTE_HOST}" "
    if [ ! -f $REMOTE_FILE ]; then
        echo '$CLUSTER_NAME: []' > $REMOTE_FILE
    fi

    # Check if multiaddr already exists in the specified cluster
    if yq eval '.$CLUSTER_NAME[] | select(. == "'$MULTIADDR'")' "$REMOTE_FILE" | grep -q .; then
        echo "Multiaddr already exists in cluster $CLUSTER_NAME"
        exit 0
    fi

    # Remove any existing entries with the same IP from the specified cluster
    WORKER_IP=$(echo "$MULTIADDR" | cut -d'/' -f3)
    yq eval -i 'del(.$CLUSTER_NAME[] | select(contains("/ip4/'$WORKER_IP'")))' $REMOTE_FILE
    # Check if multiaddr already exists
    if ! grep -q \"$MULTIADDR\" $REMOTE_FILE; then
        # Add new multiaddr to directPeers array
        yq eval -i '.$CLUSTER_NAME += [\"$MULTIADDR\"]' $REMOTE_FILE
        echo 'Multiaddr added successfully'
    else
        echo 'Multiaddr already exists in the list'
    fi
    "
}


# Loop through each remote worker and publish the multiaddr
for REMOTE_WORKER in $REMOTE_WORKERS; do
    IP=$(echo $REMOTE_WORKER | cut -d '/' -f 3)
    echo "IP: $IP"
    # Skip if IP exists in local interfaces
    if ip addr | grep -q "$IP"; then
        echo "Skipping worker $REMOTE_WORKER as IP $IP belongs to local machine"
        continue
    fi
    echo "Publishing multiaddr for $REMOTE_WORKER"
    publish_multiaddr $REMOTE_WORKER
done
