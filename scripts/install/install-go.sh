#!/bin/bash
log "Installing Go"
GO_COMPRESSED_FILE=go1.20.14.linux-amd64.tar.gz
wget https://go.dev/dl/$GO_COMPRESSED_FILE
tar -xvf $GO_COMPRESSED_FILE
mv go $GO_BIN_DIR

file_exists $GOROOT

remove_file $GO_COMPRESSED_FILE false

append_to_file $BASHRC_FILE "export GOROOT=$GOROOT" false
append_to_file $BASHRC_FILE "export GOPATH=$GOPATH" false
append_to_file $BASHRC_FILE "export PATH=\$GOPATH/bin:\$GOROOT/bin:\$PATH" false

source $BASHRC_FILE