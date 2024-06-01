#!/bin/bash

PEER_ID="$(grpcurl -plaintext localhost:8337 quilibrium.node.node.pb.NodeService.GetNodeInfo 2> /dev/null | grep -oP '"peerId":\s*"\K[^"]+')"

# Check if a Peer ID was found
if [ ! -n "$PEER_ID" ]; then
    # Run the node-get-peer-id script with the extracted Peer ID
    PEER_ID="$(source $QTOOLS_PATH/scripts/node-commands/node-get-peer-id.sh)"

    if [ -n "$PEER_ID" ]; then
        echo "$PEER_ID"
    fi
fi
