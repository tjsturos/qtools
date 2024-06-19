#!/bin/bash
os_arch="$(get_os_arch)"
log "Installing release files..."

qtools install-node-binary

qtools update-service
