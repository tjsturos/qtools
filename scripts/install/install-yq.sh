#!/bin/bash
# HELP: Installs \'yq\' version 4.20.1 for parsing config files.
VERSION=v4.44.2
if [[ "$OS_ARCH" == *"arm64"* ]]; then
    BINARY=yq_linux_arm64
    VERSION=v4.44.6
else
    BINARY=yq_linux_amd64
    VERSION=v4.44.2
fi
cd $QTOOLS_PATH/binaries

COMPRESSED_FILENAME=${BINARY}_${VERSION}.tar.gz

if [ ! -f $COMPRESSED_FILENAME ]; then
    sudo wget -q https://github.com/mikefarah/yq/releases/download/${VERSION}/${BINARY}.tar.gz 
    mv ${BINARY}.tar.gz $COMPRESSED_FILENAME
fi

tar -xzf $COMPRESSED_FILENAME &> /dev/null

BINARY_INSTALL_DIR=/usr/bin

if [ -f $BINARY_INSTALL_DIR/yq ]; then
    sudo rm $BINARY_INSTALL_DIR/yq
fi

sudo mv $BINARY $BINARY_INSTALL_DIR/yq
