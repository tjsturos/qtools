#!/bin/bash

# Get the default version from the release
NODE_VERSION=""
NODE_VERSION=""

BINARY_ONLY=""
OVERWRITE=""
# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --overwrite|-ow)
        OVERWRITE=true
        shift # past argument
        ;;
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

if [ -z "$NODE_VERSION" ]; then
    echo "Node version not specified. Using latest version..."
    NODE_VERSION=$(fetch_node_release_version)
fi

if [ -z "$QCLIENT_VERSION" ]; then
    echo "QClient version not specified. Using latest version..."
    QCLIENT_VERSION=$(fetch_qclient_release_version)
fi

if [ "$OVERWRITE" == "true" ]; then
    echo "Overwriting node and qclient versions"
    if [[ -f "$QUIL_NODE_PATH/node-$NODE_VERSION-$OS_ARCH" ]]; then
        rm "$QUIL_NODE_PATH/node-$NODE_VERSION-$OS_ARCH"
    fi
    if [[ -f "$QUIL_CLIENT_PATH/qclient-$QCLIENT_VERSION-$OS_ARCH" ]]; then
        rm "$QUIL_CLIENT_PATH/qclient-$QCLIENT_VERSION-$OS_ARCH"
    fi
fi

# Check if the node binary exists in $QUIL_NODE_PATH
if [[ ! -f "$QUIL_NODE_PATH/node-$NODE_VERSION-$OS_ARCH" ]]; then

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
    echo "Switching qclient link to qclient version: $VERSION"

    log "Linking link $LINKED_QCLIENT_BINARY to ${QUIL_CLIENT_PATH}/qclient-$VERSION-$OS_ARCH"
    sudo ln -sf "${QUIL_CLIENT_PATH}/qclient-$VERSION-$OS_ARCH" "${LINKED_QCLIENT_BINARY}"
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
    echo "Switching node link to node version: $VERSION"

    log "Linking link $LINKED_NODE_BINARY to ${QUIL_NODE_PATH}/node-$VERSION-$OS_ARCH"
    sudo ln -sf "${QUIL_NODE_PATH}/node-$VERSION-$OS_ARCH" "${LINKED_NODE_BINARY}"
    if [ $? -eq 0 ]; then
        log "Successfully linked $LINKED_NODE_BINARY to ${QUIL_NODE_PATH}/node-$VERSION-$OS_ARCH"
        # Persist the current node version to config after linking
        set_current_node_version "$VERSION"
    else
        log "Failed to link $LINKED_NODE_BINARY to ${QUIL_NODE_PATH}/node-$VERSION-$OS_ARCH"
        return 1
    fi
}

restart_service() {
    sudo systemctl daemon-reload

    local IS_CLUSTERING_ENABLED=$(yq '.service.clustering.enabled' $QTOOLS_CONFIG_FILE)
    if [ "$IS_CLUSTERING_ENABLED" == "true" -a "$(is_master)" == "true" ] || [ "$IS_CLUSTERING_ENABLED" == "false" ]; then
        # restart the main service
        sudo systemctl restart $QUIL_SERVICE_NAME
    fi

    # Restart any running dataworker instances
    if systemctl list-unit-files | grep -q 'dataworker@.service'; then
        log "Restarting all dataworker instances"
        sudo systemctl restart dataworker@*
    fi
}

# Check if the current symlink target matches the desired version
CURRENT_NODE_LINK=$(readlink -f "$LINKED_NODE_BINARY")
DESIRED_NODE_LINK="${QUIL_NODE_PATH}/node-$NODE_VERSION-$OS_ARCH"

if [ "$CURRENT_NODE_LINK" != "$DESIRED_NODE_LINK" ]; then
    log "Node binary link needs updating"
    update_node_link $NODE_VERSION
    log "Restarting service"
    restart_service
fi
