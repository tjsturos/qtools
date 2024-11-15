#!/bin/bash

# Get publish multiaddr settings from config
SSH_KEY_PATH=$(yq eval '.settings.publish_multiaddr.ssh_key_path' $QTOOLS_CONFIG_FILE)
REMOTE_USER=$(yq eval '.settings.publish_multiaddr.remote_user' $QTOOLS_CONFIG_FILE)
REMOTE_HOST=$(yq eval '.settings.publish_multiaddr.remote_host' $QTOOLS_CONFIG_FILE)
REMOTE_FILE=$(yq eval '.settings.publish_multiaddr.remote_file' $QTOOLS_CONFIG_FILE)
PEER_ID=$(qtools peer-id)

# Get the multiaddr
MULTIADDR=$(qtools get-multiaddr)

# Create or update the remote YAML file
ssh -i "$SSH_KEY_PATH" "${REMOTE_USER}@${REMOTE_HOST}" "
if [ ! -f $REMOTE_FILE ]; then
    echo 'directPeers: []' > $REMOTE_FILE
fi

# Remove any existing entries with the same peer-id
yq eval -i \"del(.directPeers[] | select(contains(\"'$PEER_ID'\")))\" $REMOTE_FILE

# Check if multiaddr already exists
if ! grep -q \"$MULTIADDR\" $REMOTE_FILE; then
    # Add new multiaddr to directPeers array
    yq eval -i '.directPeers += [\"$MULTIADDR\"]' $REMOTE_FILE
    echo 'Multiaddr added successfully'
else
    echo 'Multiaddr already exists in the list'
fi
"
