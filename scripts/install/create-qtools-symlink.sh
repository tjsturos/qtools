#!/bin/bash
# HELP: Installs the qtools shortcut to allow it to be used anywhere.

if [[ -L "$QTOOLS_BIN_PATH" ]]; then
    log "Removing existing qtools shortcut"
    rm "$QTOOLS_BIN_PATH"
fi

ln -s "$QTOOLS_PATH/qtools.sh" "$QTOOLS_BIN_PATH"

if [[ -L "$QTOOLS_BIN_PATH" ]]; then
    log "Successfully added QTools shortcut"
else 
    log "Failed to add QTools shortcut"
fi