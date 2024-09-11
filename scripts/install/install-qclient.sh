#!/bin/bash
# HELP: Installs the latest qclient from the CDN.

CURRENT_QCLIENT_BINARY="$(get_versioned_qclient)"

if [ ! -f "$QUIL_CLIENT_PATH/$CURRENT_QCLIENT_BINARY" ]; then
    qclient_files=$(fetch_available_files "https://releases.quilibrium.com/qclient-release")
    
    mkdir -p $QUIL_CLIENT_PATH
    get_remote_quil_files qclient_files[@] $QUIL_CLIENT_PATH

    if [ -f $QUIL_CLIENT_PATH/$CURRENT_QCLIENT_BINARY ]; then
        sudo chmod +x $QUIL_CLIENT_PATH/$CURRENT_QCLIENT_BINARY

        if [ -s $QUIL_QCLIENT_BIN ]; then
            rm $QUIL_QCLIENT_BIN
        fi

        sudo ln -s $QUIL_CLIENT_PATH/$CURRENT_QCLIENT_BINARY $QUIL_QCLIENT_BIN
    fi
fi