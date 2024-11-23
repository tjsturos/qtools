#!/bin/bash
# HELP: Prints this node\'s version that is running in the service.


cd $QUIL_NODE_PATH

SIGNATURE_CHECK=$(yq '.service.signature_check // ""' $QTOOLS_CONFIG_FILE)

OUTPUT="$($LINKED_NODE_BINARY ${SIGNATURE_CHECK:+--signature-check=false} --node-info)"

VERSION="$(echo "$OUTPUT" | grep -oP 'Version: \K.*')"

if [ -n "$VERSION" ]; then
    echo "$VERSION"
else
    log "Could not find node version."
fi
 
