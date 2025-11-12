#!/bin/bash
# HELP: Installs Go 1.22.4 on this node.

GO_VERSION=${1:-1.24.9}

# Check if Go is already installed and matches target version
if command_exists go; then
    CURRENT_VERSION=$(go version 2>/dev/null | awk '{print $3}' | sed 's/go//')
    if [ -n "$CURRENT_VERSION" ] && [ "$CURRENT_VERSION" == "$GO_VERSION" ]; then
        log "Go version $GO_VERSION is already installed. Skipping installation."
        exit 0
    elif [ -n "$CURRENT_VERSION" ]; then
        log "Go version $CURRENT_VERSION is installed, but target version is $GO_VERSION. Proceeding with installation."
    else
        log "Go is installed but version check failed. Proceeding with installation."
    fi
fi

echo "Installing Go"

GO_BIN_DIR=/usr/local
GOROOT=$GO_BIN_DIR/go
GOPATH=$HOME/go

if [[ "$OS_ARCH" == *"arm64"* ]] || [[ "$OS_ARCH" == *"aarch64"* ]]; then
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