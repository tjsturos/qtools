#!/bin/bash
# HELP: Fetches a dev build from a remote server and sets it up as the active node binary
# Usage: qtools fetch-dev-binary [--path <remote_file_path>]

# Parse command line arguments
REMOTE_FILE_PATH_OVERRIDE=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --path)
            REMOTE_FILE_PATH_OVERRIDE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: qtools fetch-dev-binary [--path <remote_file_path>]"
            exit 1
            ;;
    esac
done

log "Fetching dev binary from remote server..."

# Read configuration values
SSH_USER=$(yq '.dev.remote_build.ssh_user // ""' $QTOOLS_CONFIG_FILE)
SSH_HOSTNAME=$(yq '.dev.remote_build.ssh_hostname // ""' $QTOOLS_CONFIG_FILE)
REMOTE_FILE_PATH=$(yq '.dev.remote_build.file_path // ""' $QTOOLS_CONFIG_FILE)
SSH_IDENTITY=$(yq '.dev.remote_build.ssh_identity // ""' $QTOOLS_CONFIG_FILE)

# Override REMOTE_FILE_PATH if --path was provided
if [ -n "$REMOTE_FILE_PATH_OVERRIDE" ]; then
    REMOTE_FILE_PATH="$REMOTE_FILE_PATH_OVERRIDE"
fi

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

# Determine local file paths
REMOTE_FILENAME=$(basename "$REMOTE_FILE_PATH")
LOCAL_FILE_PATH="$QUIL_NODE_PATH/$REMOTE_FILENAME"
PENDING_FILE_PATH="$QUIL_NODE_PATH/node-pending"

log "Configuration:"
log "  SSH User: $SSH_USER"
log "  SSH Hostname: $SSH_HOSTNAME"
log "  Remote File: $REMOTE_FILE_PATH"
log "  Pending File: $PENDING_FILE_PATH"
log "  Final File: $LOCAL_FILE_PATH"
if [ -n "$SSH_IDENTITY" ] && [ "$SSH_IDENTITY" != "null" ]; then
    log "  SSH Identity: $SSH_IDENTITY"
fi

# Step 1: Start download and stop operations simultaneously
log "Step 1: Starting download and stop operations simultaneously..."

# Ensure the local directory exists with proper ownership
sudo mkdir -p "$(dirname "$PENDING_FILE_PATH")"
if id "quilibrium" &>/dev/null; then
    sudo chown quilibrium:$QTOOLS_GROUP "$(dirname "$PENDING_FILE_PATH")" 2>/dev/null || true
fi

# Function to download the binary
download_binary() {
    log "Downloading file from remote server as node-pending..."

    local SFTP_EXIT_CODE=0

    # Use sftp in batch mode to download the file
    if [ -n "$SSH_IDENTITY" ] && [ "$SSH_IDENTITY" != "null" ]; then
        # Use identity file if provided
        sftp -i "$SSH_IDENTITY" -b - "$SSH_USER@$SSH_HOSTNAME" <<EOF
get $REMOTE_FILE_PATH $PENDING_FILE_PATH
quit
EOF
        SFTP_EXIT_CODE=$?
    else
        # Skip identity flag if null
        sftp -b - "$SSH_USER@$SSH_HOSTNAME" <<EOF
get $REMOTE_FILE_PATH $PENDING_FILE_PATH
quit
EOF
        SFTP_EXIT_CODE=$?
    fi

    if [ $SFTP_EXIT_CODE -ne 0 ]; then
        log "Error: Failed to download file from remote server"
        return 1
    fi

    if [ ! -f "$PENDING_FILE_PATH" ]; then
        log "Error: Downloaded file not found at $PENDING_FILE_PATH"
        return 1
    fi

    log "Successfully downloaded file to $PENDING_FILE_PATH"
    return 0
}

# Function to stop node and wait for it to fully stop
stop_node_and_wait() {
    log "Stopping the current node..."
    qtools stop

    log "Waiting for node process to fully stop..."
    MAX_WAIT=30
    WAIT_COUNT=0

    # Get the resolved binary path that the symlink points to (if symlink exists)
    RESOLVED_BINARY=""
    if [ -L "$LINKED_NODE_BINARY" ]; then
        RESOLVED_BINARY=$(readlink -f "$LINKED_NODE_BINARY" 2>/dev/null || echo "")
    fi

    while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
        # Check if any node processes are still running
        # Check both the symlink path and resolved binary path
        NODE_RUNNING=false
        if [ -n "$RESOLVED_BINARY" ] && pgrep -f "$RESOLVED_BINARY" | grep -v $$ > /dev/null 2>&1; then
            NODE_RUNNING=true
        elif pgrep -f "$LINKED_NODE_BINARY" | grep -v $$ > /dev/null 2>&1; then
            NODE_RUNNING=true
        elif pgrep -f "node.*--core" | grep -v $$ > /dev/null 2>&1; then
            # Also check for worker processes
            NODE_RUNNING=true
        fi

        if [ "$NODE_RUNNING" = true ]; then
            sleep 1
            WAIT_COUNT=$((WAIT_COUNT + 1))
        else
            log "Node process has stopped"
            break
        fi
    done

    if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
        log "Warning: Node process may still be running after ${MAX_WAIT}s wait"
    fi

    return 0
}

# Start both operations in parallel
DOWNLOAD_PID=""
STOP_PID=""

# Start download in background
download_binary &
DOWNLOAD_PID=$!

# Start stop and wait in background
stop_node_and_wait &
STOP_PID=$!

# Wait for both operations to complete
log "Waiting for download and stop operations to complete..."
DOWNLOAD_EXIT_CODE=0
STOP_EXIT_CODE=0

wait $DOWNLOAD_PID
DOWNLOAD_EXIT_CODE=$?

wait $STOP_PID
STOP_EXIT_CODE=$?

# Check if either operation failed
if [ $DOWNLOAD_EXIT_CODE -ne 0 ]; then
    log "Error: Download operation failed"
    exit 1
fi

if [ $STOP_EXIT_CODE -ne 0 ]; then
    log "Error: Stop operation failed"
    exit 1
fi

log "Both download and stop operations completed successfully"

# Step 2: Replace the node binary with node-pending
log "Step 2: Replacing node binary with node-pending..."
if [ -f "$LOCAL_FILE_PATH" ]; then
    log "Removing old binary: $LOCAL_FILE_PATH"
    sudo rm -f "$LOCAL_FILE_PATH"
fi

sudo mv "$PENDING_FILE_PATH" "$LOCAL_FILE_PATH"
if [ $? -ne 0 ]; then
    log "Error: Failed to move node-pending to final location"
    exit 1
fi

log "Successfully moved node-pending to $LOCAL_FILE_PATH"

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
