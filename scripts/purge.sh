#!/bin/bash

# Stop the ceremonyclient service
qtools stop

# make a backup of the keys
qtools make-backup

# remove old node code
remove_directory $QUIL_PATH
remove_file $QUIL_GO_NODE_BIN

cd /root/
# reinstall
git clone $SOURCE_URL

qtools install-node-binary

qtools restore-backup

qtools start


