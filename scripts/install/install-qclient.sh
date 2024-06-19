#!/bin/bash

CURRENT_QCLIENT_BINARY="$(get_versioned_qclient)"

if [ ! -f "$QUIL_CLIENT_PATH/$CURRENT_QCLIENT_BINARY" ]; then
    qclient_files=$(fetch_available_files "https://releases.quilibrium.com/qclient-release")
    
    get_remote_quil_files $qclient_files $QUIL_CLIENT_PATH
    
    sudo chmod +x $QUIL_CLIENT_PATH/$CURRENT_QCLIENT_BINARY

    if [ -s $QUIL_QCLIENT_BIN ]; then
        rm $QUIL_QCLIENT_BIN
    fi

    ln -s $QUIL_CLIENT_PATH/$CURRENT_QCLIENT_BINARY $QUIL_QCLIENT_BIN
fi