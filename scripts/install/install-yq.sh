
VERSION=v4.2.0
BINARY=yq_linux_amd64
COMPRESSED_FILENAME=${BINARY}.tar.gz
wget -q https://github.com/mikefarah/yq/releases/download/${VERSION}/${COMPRESSED_FILENAME} 
tar -xzf $COMPRESSED_FILENAME &> /dev/null
mv $BINARY /usr/bin/yq
remove_file $COMPRESSED_FILENAME false