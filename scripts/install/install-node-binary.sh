#!/bin/bash

OS_ARCH="$(get_os_arch)"
log "Downloading release files..."

mkdir -p $QUIL_NODE_PATH

node_files=$(fetch_available_files "https://releases.quilibrium.com/release")

get_remote_quil_files node_files[@] $QUIL_NODE_PATH

sudo chmod +x $QUIL_NODE_PATH/$(get_versioned_node)
