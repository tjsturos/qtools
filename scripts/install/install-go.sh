#!/bin/bash
# HELP: Installs Go on this node using the version specified in the config file.
log "Installing Go"

GO_VERSION=$(yq '.settings.install.go.version' $QTOOLS_CONFIG_FILE)

brew install go@${GO_VERSION}

if command_exists go; then
    log "Go installed successfully. Version: $(go version)"
else
    log "Failed to install Go"
fi