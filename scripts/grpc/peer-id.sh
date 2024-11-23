#!/bin/bash
# HELP: Gets this node\'s Peer ID. Attempts to use grpcurl to get the peer id, but in the event of failure, will use the node binary\'s -peer-id command.
# Run the node-get-peer-id script with the extracted Peer ID
cd $QUIL_NODE_PATH

# First try to get peer ID via gRPC
PEER_ID=$(grpcurl -plaintext -max-msg-sz 5000000 localhost:8337 quilibrium.node.node.pb.NodeService.GetPeerInfo 2>/dev/null | grep -oP '"peerId":\s*"\K[^"]*')

if [ -n "$PEER_ID" ]; then
    echo "$PEER_ID"
    exit 0
fi

# If gRPC fails, check if signature check is disabled
SIGNATURE_CHECK=$(systemctl cat quilibriumd.service 2>/dev/null | grep -oP '\-\-signature\-check\s+false')

OUTPUT="$($LINKED_NODE_BINARY ${SIGNATURE_CHECK:+--signature-check=false} --peer-id)"

PEER_ID="$(echo "$OUTPUT" | grep -oP 'Peer ID: \K.*')"

if [ -n "$PEER_ID" ]; then
    echo "$PEER_ID"
else
    log "Could not find Peer ID."
fi
 
