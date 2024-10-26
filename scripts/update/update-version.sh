#!/bin/bash

# Get the default version from the release
NODE_VERSION=""
NODE_VERSION=""

BINARY_ONLY=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --node-version)
        log "Overriding node version to $2"
        NODE_VERSION="$2"
        shift # past argument
        shift # past value
        ;;
        --qclient-version)
        log "Overriding qclient version to $2"
        QCLIENT_VERSION="$2"
        shift # past argument
        shift # past value
        ;;
        --no-signatures)
        BINARY_ONLY=true
        shift # past argument
        ;;
        *)    # unknown option
        log "Unknown parameter: $1"
        shift # past argument
        ;;
    esac
done


# Check if the node binary exists in $QUIL_NODE_PATH
if [[ ! -f "$QUIL_NODE_PATH/node-$NODE_VERSION-$OS_ARCH" ]] || [[ -z "$NODE_VERSION" ]] || [[ -z "$QCLIENT_VERSION" ]]; then

    if [ -z "$NODE_VERSION" ]; then
        echo "Node version not specified. Using latest version..."
    fi

    if [ -z "$QCLIENT_VERSION" ]; then
        echo "QClient version not specified. Using latest version..."
    fi

    qtools download-node${BINARY_ONLY:+ --no-signatures}${NODE_VERSION:+ --version $NODE_VERSION}
    qtools download-qclient${BINARY_ONLY:+ --no-signatures}${QCLIENT_VERSION:+ --version $QCLIENT_VERSION}
    # Check again after download
    if [ ! -f "$QUIL_NODE_PATH/node-$NODE_VERSION-$OS_ARCH" ]; then
        echo "Error: Failed to download node binary. Please check your network connection and try again."
        exit 1
    fi
else
    echo "Node binary found: $QUIL_NODE_PATH/node-$NODE_VERSION-$OS_ARCH"
fi

update_qclient_link() {
    local VERSION=$1
    echo "Switching to qclient version: $VERSION"
    if [ -L "$LINKED_QCLIENT_BINARY" ]; then
        log "Removing existing link $LINKED_QCLIENT_BINARY"
        sudo rm $LINKED_QCLIENT_BINARY
        if [ $? -eq 0 ]; then
            log "Successfully removed existing link $LINKED_QCLIENT_BINARY"
        else
            log "Failed to remove existing link $LINKED_QCLIENT_BINARY"
            return 1
        fi
    fi
    log "Linking link $LINKED_QCLIENT_BINARY to ${QUIL_CLIENT_PATH}/qclient-$VERSION-$OS_ARCH"
    sudo ln -s "${QUIL_CLIENT_PATH}/qclient-$VERSION-$OS_ARCH" "${LINKED_QCLIENT_BINARY}"
    if [ $? -eq 0 ]; then
        log "Successfully linked $LINKED_QCLIENT_BINARY to ${QUIL_CLIENT_PATH}/qclient-$VERSION-$OS_ARCH"
    else
        log "Failed to link $LINKED_QCLIENT_BINARY to ${QUIL_CLIENT_PATH}/qclient-$VERSION-$OS_ARCH"
        return 1
    fi
}

if [ -f "$QUIL_CLIENT_PATH/qclient-$QCLIENT_VERSION-$OS_ARCH" ]; then
    update_qclient_link $QCLIENT_VERSION
else
    echo "QClient binary not found in $QUIL_CLIENT_PATH. Skipping update."
fi

update_node_link() {
    local VERSION=$1
    echo "Switching to node version: $VERSION"

    if [ -L "$LINKED_NODE_BINARY" ]; then
        log "Removing existing link $LINKED_NODE_BINARY"
        sudo rm $LINKED_NODE_BINARY
        if [ $? -eq 0 ]; then
            log "Successfully removed existing link $LINKED_NODE_BINARY"
        else
            log "Failed to remove existing link $LINKED_NODE_BINARY"
            return 1
        fi
    fi
    log "Linking link $LINKED_NODE_BINARY to ${QUIL_NODE_PATH}/node-$VERSION-$OS_ARCH"
    sudo ln -s "${QUIL_NODE_PATH}/node-$VERSION-$OS_ARCH" "${LINKED_NODE_BINARY}"
    if [ $? -eq 0 ]; then
        log "Successfully linked $LINKED_NODE_BINARY to ${QUIL_NODE_PATH}/node-$VERSION-$OS_ARCH"
    else
        log "Failed to link $LINKED_NODE_BINARY to ${QUIL_NODE_PATH}/node-$VERSION-$OS_ARCH"
        return 1
    fi
}

restart_service() {
    sudo systemctl daemon-reload
    sudo systemctl restart $QUIL_SERVICE_NAME
}

update_node_link $NODE_VERSION
restart_service
