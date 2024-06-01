#!/bin/bash

# Run the grpcurl command and capture its output
OUTPUT=$(grpcurl -plaintext -max-msg-sz 5000000 localhost:8337 quilibrium.node.node.pb.NodeService.GetPeerInfo)

# Extract the Peer ID from the output
PEER_ID=$(echo "$OUTPUT" | grep -oP 'Peer ID: \K.*')

# Check if a Peer ID was found
if [ ! -n "$PEER_ID" ]; then
    # Run the node-get-peer-id script with the extracted Peer ID
    PEER_ID="$($QTOOLS_PATH/scripts/node-commands/node-get-peer-id.sh)"

    if [ -n "$PEER_ID" ]; then
        echo "$PEER_ID"
    fi
fi