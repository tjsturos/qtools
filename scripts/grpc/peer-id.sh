#!/bin/bash
# HELP: Gets this node's Peer ID. Attempts to use grpcurl to get the peer id, but in the event of failure, will use the node binary's -peer-id command.

PEER_ID="$(grpcurl -plaintext localhost:8337 quilibrium.node.node.pb.NodeService.GetNodeInfo 2> /dev/null | grep 'peerId' | cut -d':' -f2 | sed -E 's/.*\"([^)]+)\".*/\1/')"

# Check if a Peer ID was found
if [ -z "$PEER_ID" ]; then
    # Use the node binary's -peer-id command
    cd "$QUIL_NODE_PATH"

    QUIL_BIN="$(get_versioned_node)"

    OUTPUT="$($QUIL_NODE_PATH/$QUIL_BIN -peer-id)"

    PEER_ID="$(echo "$OUTPUT" | sed -n 's/Peer ID: //p')"

    if [ -z "$PEER_ID" ]; then
        exit 1
    fi
fi

echo "$PEER_ID"
