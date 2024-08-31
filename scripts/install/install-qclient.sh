#!/bin/bash
# HELP: Installs the latest qclient from the CDN.

CURRENT_QCLIENT_BINARY="$(get_versioned_qclient)"

# Ensure the directory exists
if [ ! -d "$QUIL_CLIENT_PATH" ]; then
    mkdir -p "$QUIL_CLIENT_PATH"
fi

log "QUIL_CLIENT_PATH: $QUIL_CLIENT_PATH"
log "CURRENT_QCLIENT_BINARY: $CURRENT_QCLIENT_BINARY"

if [ ! -f "$QUIL_CLIENT_PATH/$CURRENT_QCLIENT_BINARY" ]; then
    qclient_files=$(fetch_available_files "https://releases.quilibrium.com/qclient-release")
    
    get_remote_quil_files qclient_files[@] "$QUIL_CLIENT_PATH"

    if [ -f "$QUIL_CLIENT_PATH/$CURRENT_QCLIENT_BINARY" ]; then
        sudo chmod +x "$QUIL_CLIENT_PATH/$CURRENT_QCLIENT_BINARY"

        if [ -L "$QUIL_QCLIENT_BIN" ]; then
            sudo rm "$QUIL_QCLIENT_BIN"
        fi

        sudo ln -s "$QUIL_CLIENT_PATH/$CURRENT_QCLIENT_BINARY" "$QUIL_QCLIENT_BIN"
        log "Successfully installed qclient: $CURRENT_QCLIENT_BINARY"
    else
        log "Error: Failed to download or find $CURRENT_QCLIENT_BINARY"
    fi
else
    log "qclient binary already exists: $QUIL_CLIENT_PATH/$CURRENT_QCLIENT_BINARY"
fi