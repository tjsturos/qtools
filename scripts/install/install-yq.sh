#!/bin/bash
# HELP: Installs \'yq\' version 4.20.1 for parsing config files.
VERSION="$(qyaml '.settings.install.yq.version' $QTOOLS_CONFIG_FILE)"
BINARY="$(qyaml '.settings.install.yq.binary' $QTOOLS_CONFIG_FILE)"
COMPRESSED_FILENAME=${BINARY}.tar.gz
sudo wget -q https://github.com/mikefarah/yq/releases/download/${VERSION}/${COMPRESSED_FILENAME} 
tar -xzf $COMPRESSED_FILENAME &> /dev/null

BINARY_INSTALL_DIR=$(qyaml '.settings.install.yq.binary_install_dir' $QTOOLS_CONFIG_FILE)

if [ -f $BINARY_INSTALL_DIR/yq ]; then
    sudo rm $BINARY_INSTALL_DIR/yq
fi

sudo mv $BINARY $BINARY_INSTALL_DIR/yq
sudo rm $COMPRESSED_FILENAME