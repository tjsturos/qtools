#!/bin/bash
# HELP: Installs Go 1.22.4 on this node.
log "Installing Go"
GO_COMPRESSED_FILE=go1.22.4.linux-amd64.tar.gz

log "Downloading $GO_COMPRESSED_FILE..."
wget https://go.dev/dl/$GO_COMPRESSED_FILE 

log "Uncompressing $GO_COMPRESSED_FILE"
tar -xvf $GO_COMPRESSED_FILE &> /dev/null

if [ -d $GOROOT ]; then
    sudo rm -r $GOROOT
fi

sudo mv go $GOROOT

file_exists $GOROOT

remove_file $GO_COMPRESSED_FILE false

append_to_file $BASHRC_FILE "export GOROOT=$GOROOT" false
append_to_file $BASHRC_FILE "export GOPATH=$GOPATH" false
append_to_file $BASHRC_FILE "export PATH=\$GOPATH/bin:\$GOROOT/bin:\$PATH" false

source $BASHRC_FILE