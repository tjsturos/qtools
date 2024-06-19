#!/bin/bash
BACKUP_DIR=~/quil-backup
# Create the directory if it doesn't exist
mkdir -p $BACKUP_DIR

if [ -d $QUIL_NODE_PATH/.config ]; then
    # Check if the files exist (node)
    # Copy the files
    rsync -avz --ignore-existing -e ssh "$QUIL_NODE_PATH/.config" "$BACKUP_DIR"

    log "Quilibrium $QUIL_NODE_PATH/.config directory backed up to $BACKUP_DIR"
elif [ -d ~/ceremonyclient/.config ]; then
    # Check if the files exist (docker)
    # Copy the files
    rsync -avz --ignore-existing -e ssh "$QUIL_PATH/.config" "$BACKUP_DIR"

    log "Quilibrium $QUIL_PATH/.config directory backed up to $BACKUP_DIR backed up to $BACKUP_DIR"
else
    log "One or both of the files keys.yml and config.yml do not exist."
    exit 1
fi