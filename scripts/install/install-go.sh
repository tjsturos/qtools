#!/bin/bash
# HELP: Installs Go on this node using the version specified in the config file.
log "Installing Go"

GO_VERSION=$(yq '.settings.install.go.version' $QTOOLS_CONFIG_FILE)

# Check if Go is already installed
if command_exists go; then
    log "Go is already installed. Uninstalling before reinstalling."
    brew uninstall go
fi

# Ensure we have the latest Homebrew formulas
brew update

brew install go@${GO_VERSION}

if command_exists go; then
    log "Go installed successfully. Version: $(go version)"
else
    log "Failed to install Go"
fi