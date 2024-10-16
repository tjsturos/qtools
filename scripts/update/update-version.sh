#!/bin/bash

# Get the default version from the release
NODE_VERSION=$(fetch_release_version)
QCLIENT_VERSION=$(fetch_qclient_version)

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --node-version)
        NODE_VERSION="$2"
        shift # past argument
        shift # past value
        ;;
        --qclient-version)
        QCLIENT_VERSION="$2"
        shift # past argument
        shift # past value
        ;;
        *)    # unknown option
        shift # past argument
        ;;
    esac
done



# Check if the node binary exists in $QUIL_NODE_PATH
if [ ! -f "$QUIL_NODE_PATH/node-$NODE_VERSION-$OS_ARCH" ]; then
    echo "Node binary not found in $QUIL_NODE_PATH. Downloading latest binaries..."
    qtools download-quil-binaries
    
    # Check again after download
    if [ ! -f "$QUIL_NODE_PATH/node-$NODE_VERSION-$OS_ARCH" ]; then
        echo "Error: Failed to download node binary. Please check your network connection and try again."
        exit 1
    fi
else
    echo "Node binary found in $QUIL_NODE_PATH"
fi

if [ -f "$QUIL_CLIENT_PATH/qclient-$QCLIENT_VERSION-$OS_ARCH" ]; then
    update_qclient_link $QCLIENT_VERSION
else
    echo "QClient binary not found in $QUIL_CLIENT_PATH. Skipping update."
fi

update_node_link() {
    local VERSION=$1
    echo "Switching to node version: $VERSION"
    rm $LINKED_BINARY
    ln -s $QUIL_NODE_PATH/node-$VERSION-$OS_ARCH $LINKED_BINARY
}

update_qclient_link() {
    local VERSION=$1
    echo "Switching to qclient version: $VERSION"
    rm $LINKED_QCLIENT_BINARY
    ln -s $QUIL_CLIENT_PATH/qclient-$VERSION-$OS_ARCH $LINKED_QCLIENT_BINARY
}

restart_service() {
    sudo systemctl daemon-reload
    sudo systemctl restart $QUIL_SERVICE_NAME
}

update_node_link $NODE_VERSION
restart_service
