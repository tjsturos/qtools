#!/bin/bash
BACKUP_DIR=$USER_HOME/quil-backup
# Create the directory if it doesn't exist
mkdir -p $BACKUP_DIR

if [ -f ~/ceremonyclient/node/.config/keys.yml ] && [ -f ~/ceremonyclient/node/.config/config.yml ]; then
    # Check if the files exist (node)
    # Copy the files
    cp ~/ceremonyclient/node/.config/keys.yml $BACKUP_DIR
    cp ~/ceremonyclient/node/.config/config.yml $BACKUP_DIR

    log "Quilibrium ~/ceremonyclient/node/.config/keys.yml and ~/ceremonyclient/node/.config/config.yml backed up to $BACKUP_DIR"
elif [ -f ~/ceremonyclient/.config/keys.yml ] && [ -f ~/ceremonyclient/.config/config.yml ]; then
    # Check if the files exist (docker)
    # Copy the files
    cp ~/ceremonyclient/.config/keys.yml $BACKUP_DIR
    cp ~/ceremonyclient/.config/config.yml $BACKUP_DIR

    log "Quilibrium ~/ceremonyclient/.config/keys.yml and ~/ceremonyclient/.config/config.yml backed up to $BACKUP_DIR"
else
    log "One or both of the files keys.yml and config.yml do not exist."
fi