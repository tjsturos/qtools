#!/bin/bash
# HELP: Installs 'yq' for parsing config files.

echo "Debug: QTOOLS_CONFIG_FILE = $QTOOLS_CONFIG_FILE"
echo "Debug: Content of QTOOLS_CONFIG_FILE:"
cat $QTOOLS_CONFIG_FILE

echo "Debug: Attempting to get yq version..."
VERSION=$(qyaml '.settings.install.yq.version' $QTOOLS_CONFIG_FILE)
echo "Debug: Returned VERSION = $VERSION"

if [[ -z "$VERSION" || "$VERSION" == "Value not found." ]]; then
    log "Error: yq version not found or empty in config file."
    exit 1
fi

echo "Debug: VERSION = $VERSION"

OS_ARCH="$(get_os_arch)"

case "$OS_ARCH" in
    linux-amd64)
        BINARY="yq_linux_amd64"
        ;;
    linux-arm64)
        BINARY="yq_linux_arm64"
        ;;
    darwin-amd64)
        BINARY="yq_darwin_amd64"
        ;;
    darwin-arm64)
        BINARY="yq_darwin_arm64"
        ;;
    *)
        log "Unsupported OS/architecture: $OS_ARCH"
        exit 1
        ;;
esac

cd $QTOOLS_PATH/binaries

COMPRESSED_FILENAME=${BINARY}_${VERSION}.tar.gz

if [[ ! -f $COMPRESSED_FILENAME ]]; then
    log "Downloading yq version $VERSION for $OS_ARCH..."
    sudo wget -q https://github.com/mikefarah/yq/releases/download/${VERSION}/${BINARY}.tar.gz 
    mv ${BINARY}.tar.gz $COMPRESSED_FILENAME
fi

log "Extracting yq..."
tar -xzf $COMPRESSED_FILENAME &> /dev/null

BINARY_INSTALL_DIR=$(qyaml '.settings.install.yq.binary_install_dir' $QTOOLS_CONFIG_FILE)

if [[ -f $BINARY_INSTALL_DIR/yq ]]; then
    log "Removing existing yq binary..."
    sudo rm $BINARY_INSTALL_DIR/yq
fi

log "Installing yq..."
sudo mv yq $BINARY_INSTALL_DIR/yq

if command_exists yq; then
    log "yq installed successfully. Version: $(yq --version)"
else
    log "Failed to install yq. Please check the installation process."
    exit 1
fi