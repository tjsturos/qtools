#!/bin/bash

# Get the multiaddr
LOCAL_MULTIADDR=$(qtools get-multiaddr)

# Get publish multiaddr settings from config
SSH_KEY_PATH=$(yq eval '.settings.publish_multiaddr.ssh_key_path' $QTOOLS_CONFIG_FILE)
REMOTE_USER=$(yq eval '.settings.publish_multiaddr.remote_user' $QTOOLS_CONFIG_FILE)
REMOTE_HOST=$(yq eval '.settings.publish_multiaddr.remote_host' $QTOOLS_CONFIG_FILE)
REMOTE_FILE=$(yq eval '.settings.publish_multiaddr.remote_file' $QTOOLS_CONFIG_FILE)

# Pull the remote YAML file
TEMP_FILE=$(mktemp)
scp -i "$SSH_KEY_PATH" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_FILE}" $TEMP_FILE

# Update local config with remote peers
REMOTE_PEERS=$(yq eval '.directPeers[]' $TEMP_FILE)
yq eval -i ".p2p.directPeers = []" $QUIL_CONFIG_FILE

# Add each remote peer to local config, excluding our own multiaddr
for peer in $REMOTE_PEERS; do
    if [ "$peer" != "$LOCAL_MULTIADDR" ]; then
        echo "Adding peer $peer to local config"
        yq eval -i ".p2p.directPeers += [\"$peer\"]" $QUIL_CONFIG_FILE
    fi
done

# Cleanup
rm $TEMP_FILE

qtools restart
