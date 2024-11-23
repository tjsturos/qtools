#!/bin/bash
# HELP: Prints this node\'s version that is running in the service.

OUTPUT="$(run_node_command --node-info)"

VERSION="$(echo "$OUTPUT" | grep -oP 'Version: \K.*')"

if [ -n "$VERSION" ]; then
    echo "$VERSION"
else
    log "Could not find node version."
fi
 
