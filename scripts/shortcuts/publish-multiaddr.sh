#!/bin/bash

# Get publish multiaddr settings from config
SSH_KEY_PATH=$(yq eval '.settings.central_server.ssh_key_path' $QTOOLS_CONFIG_FILE)
REMOTE_USER=$(yq eval '.settings.central_server.remote_user' $QTOOLS_CONFIG_FILE)
REMOTE_HOST=$(yq eval '.settings.central_server.remote_host' $QTOOLS_CONFIG_FILE)
REMOTE_FILE=$(yq eval '.settings.publish_multiaddr.remote_file' $QTOOLS_CONFIG_FILE)

INTERNAL_IP=""
# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --internal)
            INTERNAL_IP="true"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

PEER_ID=$(qtools peer-id)

# Get the multiaddr
MULTIADDR=$(qtools get-multiaddr ${INTERNAL_IP:+"--internal"})

# Validate peer ID format
if [[ ! "$PEER_ID" =~ ^Qm ]]; then
    echo "Error: Peer ID must start with 'Qm'. Current peer ID: $PEER_ID"
    exit 1
fi

# Validate multiaddr format
if [[ ! "$MULTIADDR" =~ ^/ip4/ ]] || [[ ! "$MULTIADDR" =~ /p2p/Qm ]]; then
    echo "Error: Multiaddr must start with '/ip4/' and contain '/p2p/Qm'. Current multiaddr: $MULTIADDR"
    exit 1
fi

IP=$(hostname -I | awk '{print $1}')

# Create or update the remote YAML file
ssh -i "$SSH_KEY_PATH" "${REMOTE_USER}@${REMOTE_HOST}" "
if [ ! -f $REMOTE_FILE ]; then
    echo 'directPeers: []' > $REMOTE_FILE
fi

# Check if multiaddr already exists
if grep -q "$MULTIADDR" "$REMOTE_FILE"; then
    echo 'Multiaddr already exists in the list'
    exit 0
fi


# Remove any existing entries with the same peer-id or IP
yq eval -i 'del(.directPeers[] | select(test(\"$PEER_ID$\")))' $REMOTE_FILE
yq eval -i 'del(.directPeers[] | select(test(\"$IP$\")))' $REMOTE_FILE

# Check if multiaddr already exists
if ! grep -q \"$MULTIADDR\" $REMOTE_FILE; then
    # Add new multiaddr to directPeers array
    yq eval -i '.directPeers += [\"$MULTIADDR\"]' $REMOTE_FILE
    echo 'Multiaddr added successfully'
else
    echo 'Multiaddr already exists in the list'
fi
"
