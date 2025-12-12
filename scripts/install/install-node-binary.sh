#!/bin/bash
# HELP: Installs the node files from the CDN.

OS_ARCH="$(get_os_arch)"
log "Downloading release files..."

sudo mkdir -p $QUIL_NODE_PATH

# Ensure quilibrium user has access if using quilibrium user
SERVICE_USER=$(yq '.service.default_user // "quilibrium"' $QTOOLS_CONFIG_FILE 2>/dev/null || echo "quilibrium")
if [ "$SERVICE_USER" == "quilibrium" ] && id "quilibrium" &>/dev/null; then
    sudo chown -R quilibrium:quilibrium "$QUIL_NODE_PATH" 2>/dev/null || true
    # Ensure quilibrium user and group can write to the directory
    sudo chmod -R ug+w "$QUIL_NODE_PATH" 2>/dev/null || true
fi

node_files=$(fetch_available_files "https://releases.quilibrium.com/release")

get_remote_quil_files node_files[@] $QUIL_NODE_PATH

BINARY_FILE=$QUIL_NODE_PATH/$(get_release_node_version)
sudo chmod +x "$BINARY_FILE"

# Ensure quilibrium user owns the binary if using quilibrium user
if [ "$SERVICE_USER" == "quilibrium" ] && id "quilibrium" &>/dev/null; then
    sudo chown quilibrium:quilibrium "$BINARY_FILE" 2>/dev/null || true
fi
