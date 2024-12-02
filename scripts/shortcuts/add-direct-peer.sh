#!/bin/bash
# HELP: Add a direct peer to the node's config file

if [ -z "$1" ]; then
    echo "Usage: qtools add-direct-peer <peer_address>"
    echo "Example: qtools add-direct-peer /ip4/1.2.3.4/tcp/40000/p2p/12D3KooWxxxxxx"
    exit 1
fi

PEER_ADDRESS="$1"

# Extract peer ID from the address (everything after the last /p2p/)
PEER_ID=$(echo "$PEER_ADDRESS" | grep -o '/p2p/[^/]*$' | cut -d'/' -f3)

if [ -z "$PEER_ID" ]; then
    echo "Error: Invalid peer address format. Must include /p2p/ followed by peer ID"
    exit 1
fi

# Remove any existing entry with the same peer ID
yq eval "del(.p2p.directPeers[] | select(contains(\"$PEER_ID\")))" -i "$QUIL_CONFIG_FILE"

# Add the new peer address to directPeers array
yq eval ".p2p.directPeers += [\"$PEER_ADDRESS\"]" -i "$QUIL_CONFIG_FILE"

echo "Added direct peer: $PEER_ADDRESS"
echo "Restart Service  (qtools restart) to apply changes"
