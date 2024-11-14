#!/bin/bash
# HELP: Prints this node\'s version that is running in the service.


cd $QUIL_NODE_PATH

OUTPUT="$($LINKED_NODE_BINARY --node-info)"

VERSION="$(echo "$OUTPUT" | grep -oP 'Version: \K.*')"

if [ -n "$VERSION" ]; then
    echo "$VERSION"
else
    log "Could not find node version."
fi
 
