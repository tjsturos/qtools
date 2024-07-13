#!/bin/bash
# HELP: Installs \'yq\' version 4.20.1 for parsing config files.
VERSION=$(qyaml '.settings.install.yq.version' $QTOOLS_CONFIG_FILE)
BINARY=$(qyaml '.settings.install.yq.binary' $QTOOLS_CONFIG_FILE)
cd $QTOOLS_PATH/binaries

COMPRESSED_FILENAME=${BINARY}_${VERSION}.tar.gz

if [ ! -f $COMPRESSED_FILENAME ]; then
    sudo wget -q https://github.com/mikefarah/yq/releases/download/${VERSION}/${BINARY}.tar.gz 
    mv ${BINARY}.tar.gz $COMPRESSED_FILENAME
fi

tar -xzf $COMPRESSED_FILENAME &> /dev/null

BINARY_INSTALL_DIR=$(qyaml '.settings.install.yq.binary_install_dir' $QTOOLS_CONFIG_FILE)

if [ -f $BINARY_INSTALL_DIR/yq ]; then
    sudo rm $BINARY_INSTALL_DIR/yq
fi

sudo mv $BINARY $BINARY_INSTALL_DIR/yq
