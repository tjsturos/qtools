#!/bin/bash
# HELP: Installs Go on this node using the version specified in the config file.
log "Installing Go"

GO_VERSION=$(qyaml '.settings.install.go.version' $QTOOLS_CONFIG_FILE)
OS_ARCH="$(get_os_arch)"
GO_COMPRESSED_FILE="go${GO_VERSION}.${OS_ARCH}.tar.gz"
GO_DOWNLOAD_URL="https://go.dev/dl/${GO_COMPRESSED_FILE}"

log "Downloading $GO_COMPRESSED_FILE..."
wget $GO_DOWNLOAD_URL

log "Uncompressing $GO_COMPRESSED_FILE"
sudo tar -C /usr/local -xzf $GO_COMPRESSED_FILE

remove_file $GO_COMPRESSED_FILE false

append_to_file $BASHRC_FILE "export GOROOT=$GOROOT" false
append_to_file $BASHRC_FILE "export GOPATH=$GOPATH" false
append_to_file $BASHRC_FILE "export PATH=\$GOPATH/bin:\$GOROOT/bin:\$PATH" false

source $BASHRC_FILE

if command_exists go; then
    log "Go installed successfully. Version: $(go version)"
else
    log "Failed to install Go. Please check the installation process."
    exit 1
fi