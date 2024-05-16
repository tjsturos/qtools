#!/bin/bash
BACKUP_DIR=~/quil-backup
# Check if the files exist
if [ -f ~/ceremonyclient/node/keys.yml ] && [ -f ~/ceremonyclient/node/config.yml ]; then
    # Create the directory if it doesn't exist
    mkdir -p ~/quil-backup/

    # Copy the files
    cp ~/ceremonyclient/node/keys.yml $BACKUP_DIR
    cp ~/ceremonyclient/node/config.yml $BACKUP_DIR

    echo "Quilibrium key.yml and config.yml backed up to "
else
    echo "One or both of the files keys.yml and config.yml do not exist."
fi