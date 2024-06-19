#!/bin/bash
BACKUP_DIR=$HOME/quil-backup
RESTORE_DIR=$QUIL_NODE_PATH/.config

# Wait for the directory to be created if it doesn't exist
qtools stop
cp -r $BACKUP_DIR/.config $RESTORE_DIR
qtools start
