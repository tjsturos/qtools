#!/bin/bash
# HELP: Installs Go 1.22.4 on this node.
echo "Installing Go"

GO_VERSION=${1:-1.22.4}

GO_BIN_DIR=/usr/local
GOROOT=$GO_BIN_DIR/go
GOPATH=$HOME/go

if [[ "$OS_ARCH" == *"arm64"* ]]; then
    GO_COMPRESSED_FILE=go${GO_VERSION}.linux-arm64.tar.gz
else
    GO_COMPRESSED_FILE=go${GO_VERSION}.linux-amd64.tar.gz
fi

echo "Downloading $GO_COMPRESSED_FILE..."
wget https://go.dev/dl/$GO_COMPRESSED_FILE 

echo "Uncompressing $GO_COMPRESSED_FILE"
tar -xvf $GO_COMPRESSED_FILE &> /dev/null

if [ -d $GOROOT ]; then
    sudo rm -r $GOROOT
fi

sudo mv go $GOROOT

file_exists $GOROOT

remove_file $GO_COMPRESSED_FILE false

append_to_file $BASHRC_FILE "export GOROOT=$GOROOT" false
append_to_file $BASHRC_FILE "export GOPATH=$GOPATH" false
append_to_file $BASHRC_FILE "export PATH=${GOPATH}/bin:${GOROOT}/bin:\$PATH" false

source $BASHRC_FILE