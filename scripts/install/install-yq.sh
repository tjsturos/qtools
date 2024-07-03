#!/bin/bash
VERSION=v4.20.1
BINARY=yq_linux_amd64
COMPRESSED_FILENAME=${BINARY}.tar.gz
sudo wget -q https://github.com/mikefarah/yq/releases/download/${VERSION}/${COMPRESSED_FILENAME} 
tar -xzf $COMPRESSED_FILENAME &> /dev/null

if [ -f /usr/bin/yq ]; then
    rm /usr/bin/yq
fi

sudo mv $BINARY /usr/bin/yq
remove_file $COMPRESSED_FILENAME false