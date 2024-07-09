#!/bin/bash
# HELP: A shortcut to edit the node's config file.
FILE_QUIL_CONFIG="$QUIL_NODE_PATH/.config/config.yml"
install_package nano nano false
if [ -f "$FILE_QUIL_CONFIG" ]; then
    nano $FILE_QUIL_CONFIG
else
    log "Could not find config file at $FILE_QUIL_CONFIG"
fi