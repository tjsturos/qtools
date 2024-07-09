#!/bin/bash
# HELP: Gets this node\'s Peer ID. Attempts to use grpcurl to get the peer id, but in the event of failure, will use the node binary\'s -peer-id command.

PEER_ID="$(grpcurl -plaintext localhost:8337 quilibrium.node.node.pb.NodeService.GetNodeInfo 2> /dev/null | grep -oP '"peerId":\s*"\K[^"]+')"

# Check if a Peer ID was found
if [ ! -n "$PEER_ID" ]; then
    # Run the node-get-peer-id script with the extracted Peer ID
    cd $QUIL_NODE_PATH

    QUIL_BIN="$(get_versioned_node)"

    OUTPUT="$($QUIL_NODE_PATH/$QUIL_BIN -peer-id)"

    PEER_ID="$(echo "$OUTPUT" | grep -oP 'Peer ID: \K.*')"

    if [ -n "$PEER_ID" ]; then
        echo "$PEER_ID"
    else
        log "Could not find Peer ID."
    fi
else
    echo "$PEER_ID"
fi
