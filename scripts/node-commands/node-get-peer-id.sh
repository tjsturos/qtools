#!/bin/bash

cd $QUIL_NODE_PATH

QUIL_BIN="$(get_versioned_binary)"
log "Got a binary of $QUIL_BIN"

OUTPUT="$($QUIL_NODE_PATH/$QUIL_BIN -peer-id)"

echo "$(echo "$OUTPUT" | grep -oP 'Peer ID: \K.*')"
