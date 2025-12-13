#!/bin/bash
# HELP: Installs the node files from the CDN.

OS_ARCH="$(get_os_arch)"
log "Downloading release files..."

sudo mkdir -p $QUIL_NODE_PATH

# Ensure quilibrium user has access if using quilibrium user
SERVICE_USER=$(yq '.service.default_user // "quilibrium"' $QTOOLS_CONFIG_FILE 2>/dev/null || echo "quilibrium")
QTOOLS_GROUP="qtools"
if [ "$SERVICE_USER" == "quilibrium" ] && id "quilibrium" &>/dev/null; then
    sudo chown -R quilibrium:$QTOOLS_GROUP "$QUIL_NODE_PATH" 2>/dev/null || true
    # Ensure qtools group can read, write, and execute
    sudo chmod -R g+rwx "$QUIL_NODE_PATH" 2>/dev/null || true
fi

node_files=$(fetch_available_files "https://releases.quilibrium.com/release")

get_remote_quil_files node_files[@] $QUIL_NODE_PATH

BINARY_FILE=$QUIL_NODE_PATH/$(get_release_node_version)
sudo chmod +x "$BINARY_FILE"

# Ensure quilibrium user owns the binary if using quilibrium user
if [ "$SERVICE_USER" == "quilibrium" ] && id "quilibrium" &>/dev/null; then
    sudo chown quilibrium:$QTOOLS_GROUP "$BINARY_FILE" 2>/dev/null || true
    sudo chmod g+rwx "$BINARY_FILE" 2>/dev/null || true
fi
