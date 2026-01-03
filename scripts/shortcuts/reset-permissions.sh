#!/bin/bash
# HELP: Reset ownership and permissions for qtools and quil directories
# USAGE: qtools reset-permissions

log "Resetting ownership and permissions for qtools and quil directories..."

# Reset ownership and permissions for quil directory
if [ -d "$QUIL_PATH" ]; then
    log "Setting ownership of $QUIL_PATH to quilibrium:$QTOOLS_GROUP..."
    if ! sudo chown -R quilibrium:$QTOOLS_GROUP "$QUIL_PATH"; then
        log "Error: Failed to set ownership for $QUIL_PATH"
        exit 1
    fi
    
    log "Setting permissions of $QUIL_PATH to u=rwx,g=rwx,o=r..."
    if ! sudo chmod -R u=rwx,g=rwx,o=r "$QUIL_PATH"; then
        log "Error: Failed to set permissions for $QUIL_PATH"
        exit 1
    fi
    log "Successfully reset ownership and permissions for $QUIL_PATH"
else
    log "Warning: $QUIL_PATH does not exist, skipping..."
fi

# Reset ownership and permissions for qtools directory
if [ -d "$QTOOLS_PATH" ]; then
    log "Setting ownership of $QTOOLS_PATH to $USER:$QTOOLS_GROUP..."
    if ! sudo chown -R $USER:$QTOOLS_GROUP "$QTOOLS_PATH"; then
        log "Error: Failed to set ownership for $QTOOLS_PATH"
        exit 1
    fi
    
    log "Setting permissions of $QTOOLS_PATH to u=rwx,g=rwx,o=r..."
    if ! sudo chmod -R u=rwx,g=rwx,o=r "$QTOOLS_PATH"; then
        log "Error: Failed to set permissions for $QTOOLS_PATH"
        exit 1
    fi
    log "Successfully reset ownership and permissions for $QTOOLS_PATH"
else
    log "Warning: $QTOOLS_PATH does not exist, skipping..."
fi

log "Ownership and permissions reset complete."
