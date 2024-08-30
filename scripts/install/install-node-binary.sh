#!/bin/bash
# HELP: Installs the node files from the CDN.

OS_ARCH="$(get_os_arch)"
log "Downloading release files..."

mkdir -p $QUIL_NODE_PATH

node_files=$(fetch_available_files "https://releases.quilibrium.com/release")

get_remote_quil_files node_files[@] $QUIL_NODE_PATH

# Add debugging information
log "Contents of $QUIL_NODE_PATH:"
ls -l $QUIL_NODE_PATH

VERSIONED_NODE="$(get_versioned_node)"
log "Versioned node: $VERSIONED_NODE"

if [ -f "$QUIL_NODE_PATH/$VERSIONED_NODE" ]; then
    chmod +x "$QUIL_NODE_PATH/$VERSIONED_NODE"
    log "Successfully set executable permissions for $VERSIONED_NODE"
else
    log "Error: $VERSIONED_NODE not found in $QUIL_NODE_PATH"
    exit 1
fi
