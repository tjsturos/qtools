#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Stop the ceremonyclient service
systemctl stop ceremonyclient.service

# make a backup of the keys
source ./backup/local-backup.sh

# remove old node code
rm -rf /root/ceremonyclient
rm /root/go/bin/node

# reinstall
git clone https://github.com/QuilibriumNetwork/ceremonyclient.git


source $SCRIPT_DIR/backup/restore-backup.sh
cd ceremonyclient/node


GOEXPERIMENT=arenas go install ./...

systemctl start ceremonyclient.service