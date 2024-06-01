#!/bin/bash

cd $QUIL_NODE_PATH

QUIL_BIN="$(get_versioned_binary)"

OUTPUT="$(./$QUIL_BIN -peer-id)"

echo "$(echo "$OUTPUT" | grep -oP 'Peer ID: \K.*')"
