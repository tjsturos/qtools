#!/bin/bash

# Stop the ceremonyclient service
systemctl stop $QUIL_SERVICE_NAME

# make a backup of the keys
qtools make-backup

# remove old node code
remove_directory $QUIL_PATH
remove_file $QUIL_GO_NODE_BIN

cd /root/
# reinstall
git clone https://github.com/QuilibriumNetwork/ceremonyclient.git

qtools install-node-binary

qtools restore-backup

systemctl start $QUIL_SERVICE_NAME


