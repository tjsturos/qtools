
VERSION=v4.2.0
BINARY=yq_linux_amd64
COMPRESSED_FILENAME=${BINARY}.tar.gz
wget https://github.com/mikefarah/yq/releases/download/${VERSION}/${COMPRESSED_FILENAME} &> /dev/null
tar xz $COMPRESSED_FILENAME &> /dev/null
mv $BINARY /usr/bin/yq
rm $COMPRESSED_FILENAME