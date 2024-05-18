#!/bin/bash

if [ ! -d "$QUIL_CLIENT_PATH" ]; then
    wait_for_directory $QUIL_CLIENT_PATH
fi

log "Installing qClient..."
cd $QUIL_CLIENT_PATH

# Remove the file before re-installation
if [ -f "$QUIL_CLIENT_PATH/qclient" ]; then
    remove_file $QUIL_CLIENT_PATH/qclient
fi

# Install
GOEXPERIMENT=arenas go build -o /root/go/bin/qclient main.go > /dev/null 2>&1

# verify install
file_exists $QUIL_CLIENT_PATH/qclient

ln -s $QUIL_CLIENT_PATH/qclient /usr/local/bin/qclient
