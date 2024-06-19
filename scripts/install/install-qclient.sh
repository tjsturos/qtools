#!/bin/bash

CURRENT_QCLIENT_BINARY="$(get_versioned_qclient)"

if [ ! -f "$QUIL_CLIENT_PATH/$CURRENT_QCLIENT_BINARY" ]; then
    fetch_available_files "https://releases.quilibrium.com/$CURRENT_QCLIENT_BINARY"
    sudo chmod +x $QUIL_CLIENT_PATH/$CURRENT_QCLIENT_BINARY

    if [ -s $QUIL_QCLIENT_BIN ]; then
        rm $QUIL_QCLIENT_BIN
    fi

    ln -s $QUIL_CLIENT_PATH/$CURRENT_QCLIENT_BINARY $QUIL_QCLIENT_BIN
fi