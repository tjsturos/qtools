#!/bin/bash
# HELP: Installs 'yq' for parsing config files on macOS using Homebrew.
VERSION=$(yq '.settings.install.yq.version' $QTOOLS_CONFIG_FILE)

if [[ -z "$VERSION" || "$VERSION" == "null" ]]; then
    log "Error: yq version not found or empty in config file."
    exit 1
fi

log "Installing yq version $VERSION using Homebrew..."
brew install yq@$VERSION

if command_exists yq; then
    log "yq installed successfully. Version: $(yq --version)"
else
    log "Failed to install yq. Please check the installation process."
    exit 1
fi