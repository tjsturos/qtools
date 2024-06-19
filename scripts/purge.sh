#!/bin/bash

# Stop the ceremonyclient service
qtools stop

# make a backup of the keys
qtools make-backup

# remove old node code
remove_directory $QUIL_PATH

cd $HOME

source $QTOOLS_PATH/scripts/install/install-from-release.sh &

wait

qtools restore-backup

qtools start

qtools enable


