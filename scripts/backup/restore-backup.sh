#!/bin/bash
BACKUP_DIR=~/quil-backup
RESTORE_DIR=~/ceremonyclient/node/.config
# Check if the files exist
if [ -f $BACKUP_DIR/keys.yml ] && [ -f $BACKUP_DIR/config.yml ]; then
    # Copy the files
    mkdir -p $RESTORE_DIR
    cp $BACKUP_DIR/keys.yml $RESTORE_DIR
    cp $BACKUP_DIR/config.yml $RESTORE_DIR

    echo "Files copied successfully. Going for a reboot."
    reboot
else
    echo "One or both of the files keys.yml and config.yml do not exist."
fi