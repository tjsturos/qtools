#!/bin/bash
# HELP: A shortcut to edit the node\'s config file.

install_package nano nano false
if [ -f "$QUIL_CONFIG_FILE" ]; then
    nano $QUIL_CONFIG_FILE
else
    log "Could not find config file at $QUIL_CONFIG_FILE"
fi