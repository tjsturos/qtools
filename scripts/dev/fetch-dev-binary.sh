#!/bin/bash
# HELP: Fetches a dev build from a remote server and sets it up as the active node binary
# Usage: qtools fetch-dev-binary

log "Fetching dev binary from remote server..."

# Read configuration values
SSH_USER=$(yq '.dev.remote_build.ssh_user // ""' $QTOOLS_CONFIG_FILE)
SSH_HOSTNAME=$(yq '.dev.remote_build.ssh_hostname // ""' $QTOOLS_CONFIG_FILE)
REMOTE_FILE_PATH=$(yq '.dev.remote_build.file_path // ""' $QTOOLS_CONFIG_FILE)
SSH_IDENTITY=$(yq '.dev.remote_build.ssh_identity // ""' $QTOOLS_CONFIG_FILE)

# Validate required configuration
if [ -z "$SSH_USER" ] || [ "$SSH_USER" == "null" ]; then
    log "Error: dev.remote_build.ssh_user is not configured"
    exit 1
fi

if [ -z "$SSH_HOSTNAME" ] || [ "$SSH_HOSTNAME" == "null" ]; then
    log "Error: dev.remote_build.ssh_hostname is not configured"
    exit 1
fi

if [ -z "$REMOTE_FILE_PATH" ] || [ "$REMOTE_FILE_PATH" == "null" ]; then
    log "Error: dev.remote_build.file_path is not configured"
    exit 1
fi

# Determine local file path (save to QUIL_NODE_PATH with the same filename)
REMOTE_FILENAME=$(basename "$REMOTE_FILE_PATH")
LOCAL_FILE_PATH="$QUIL_NODE_PATH/$REMOTE_FILENAME"

log "Configuration:"
log "  SSH User: $SSH_USER"
log "  SSH Hostname: $SSH_HOSTNAME"
log "  Remote File: $REMOTE_FILE_PATH"
log "  Local File: $LOCAL_FILE_PATH"
if [ -n "$SSH_IDENTITY" ] && [ "$SSH_IDENTITY" != "null" ]; then
    log "  SSH Identity: $SSH_IDENTITY"
fi

# Step 1: Stop the current running node
log "Step 1: Stopping the current node..."
qtools stop

# Step 2: SFTP the file from the server
log "Step 2: Downloading file from remote server..."
# Ensure the local directory exists with proper ownership
sudo mkdir -p "$(dirname "$LOCAL_FILE_PATH")"
if id "quilibrium" &>/dev/null; then
    sudo chown quilibrium:$QTOOLS_GROUP "$(dirname "$LOCAL_FILE_PATH")" 2>/dev/null || true
fi

# Use sftp in batch mode to download the file
if [ -n "$SSH_IDENTITY" ] && [ "$SSH_IDENTITY" != "null" ]; then
    # Use identity file if provided
    sftp -i "$SSH_IDENTITY" -b - "$SSH_USER@$SSH_HOSTNAME" <<EOF
get $REMOTE_FILE_PATH $LOCAL_FILE_PATH
quit
EOF
else
    # Skip identity flag if null
    sftp -b - "$SSH_USER@$SSH_HOSTNAME" <<EOF
get $REMOTE_FILE_PATH $LOCAL_FILE_PATH
quit
EOF
fi

if [ $? -ne 0 ]; then
    log "Error: Failed to download file from remote server"
    exit 1
fi

if [ ! -f "$LOCAL_FILE_PATH" ]; then
    log "Error: Downloaded file not found at $LOCAL_FILE_PATH"
    exit 1
fi

log "Successfully downloaded file to $LOCAL_FILE_PATH"

# Step 3: chown it to quilibrium:qtools
log "Step 3: Setting ownership to quilibrium:qtools..."
sudo chown quilibrium:$QTOOLS_GROUP "$LOCAL_FILE_PATH"
if [ $? -ne 0 ]; then
    log "Error: Failed to set ownership"
    exit 1
fi

# Step 4: chmod it u=rwx,g=rwx,o=r
log "Step 4: Setting permissions to u=rwx,g=rwx,o=r..."
sudo chmod u=rwx,g=rwx,o=r "$LOCAL_FILE_PATH"
if [ $? -ne 0 ]; then
    log "Error: Failed to set permissions"
    exit 1
fi

# Step 5: Make sure the node symlink points to this file
log "Step 5: Checking if node symlink points to the correct file..."
CURRENT_LINK=$(readlink -f "$LINKED_NODE_BINARY" 2>/dev/null || echo "")

if [ -z "$CURRENT_LINK" ] || [ "$CURRENT_LINK" != "$LOCAL_FILE_PATH" ]; then
    log "Symlink does not point to the correct file. Creating/updating symlink..."
    qtools create-node-symlink --path "$LOCAL_FILE_PATH"
    if [ $? -ne 0 ]; then
        log "Error: Failed to create/update symlink"
        exit 1
    fi
else
    log "Symlink already points to the correct file: $LOCAL_FILE_PATH"
fi

# Step 6: Make sure the service has signature-check=false
log "Step 6: Checking service signature-check setting..."
CURRENT_SIG_CHECK=$(yq '.service.signature_check // "true"' $QTOOLS_CONFIG_FILE)

if [ "$CURRENT_SIG_CHECK" != "false" ]; then
    log "Service signature-check is not false. Updating service..."
    qtools update-service --skip-sig-check
    if [ $? -ne 0 ]; then
        log "Error: Failed to update service with --skip-sig-check"
        exit 1
    fi
else
    log "Service signature-check is already set to false"
fi

# Step 7: Start the node up
log "Step 7: Starting the node..."
qtools start

log "Successfully fetched and configured dev binary!"
