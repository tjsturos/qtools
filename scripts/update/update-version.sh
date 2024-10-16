#!/bin/bash

# Get the default version from the release
VERSION=$(fetch_release_version)

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --version)
        VERSION="$2"
        shift # past argument
        shift # past value
        ;;
        *)    # unknown option
        shift # past argument
        ;;
    esac
done

echo "Using version: $VERSION"

# Check if the node binary exists in $QUIL_NODE_PATH
if [ ! -f "$QUIL_NODE_PATH/node-$VERSION-$OS_ARCH" ]; then
    echo "Node binary not found in $QUIL_NODE_PATH. Downloading latest binaries..."
    qtools download-quil-binaries
    
    # Check again after download
    if [ ! -f "$QUIL_NODE_PATH/node-$VERSION-$OS_ARCH" ]; then
        echo "Error: Failed to download node binary. Please check your network connection and try again."
        exit 1
    fi
else
    echo "Node binary found in $QUIL_NODE_PATH"
fi

update_version_link() {
    local version=$1

    rm $LINKED_BINARY
    ln -s $QUIL_NODE_PATH/node-$VERSION-$OS_ARCH $LINKED_BINARY
}

restart_service() {
    sudo systemctl daemon-reload
    sudo systemctl restart $QUIL_SERVICE_NAME
}

update_version_link $VERSION
restart_service