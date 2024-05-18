#!/bin/bash

# Stop the ceremonyclient service
systemctl stop ceremonyclient.service

# make a backup of the keys
qtools make-backup

# remove old node code
rm -rf $QUIL_PATH
rm $QUIL_GO_NODE_BIN

cd /root/
# reinstall
git clone https://github.com/QuilibriumNetwork/ceremonyclient.git

qtools install-node-binary

qtools restore-backup

systemctl start ceremonyclient.service


