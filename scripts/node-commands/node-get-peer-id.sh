#!/bin/bash

cd $QUIL_NODE_PATH

QUIL_BIN="$(get_versioned_node)"

OUTPUT="$($QUIL_NODE_PATH/$QUIL_BIN -peer-id)"

echo "$(echo "$OUTPUT" | grep -oP 'Peer ID: \K.*')"
