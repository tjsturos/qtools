#!/bin/bash
# HELP: Fixes the node binary symlink to point to the correct location for quilibrium user.
# USAGE: qtools fix-node-symlink

log "Checking node binary symlink..."

# Get the service user from config
SERVICE_USER=$(yq '.service.default_user // "quilibrium"' $QTOOLS_CONFIG_FILE 2>/dev/null || echo "quilibrium")

if [ "$SERVICE_USER" != "quilibrium" ]; then
    log "Service user is not quilibrium. No fix needed."
    exit 0
fi

# Check if quilibrium user exists
if ! id "quilibrium" &>/dev/null; then
    log "Quilibrium user does not exist. Creating it..."
    qtools create-quilibrium-user
fi

# Get current symlink target
CURRENT_LINK=$(readlink -f "$LINKED_NODE_BINARY" 2>/dev/null || echo "")
if [ -z "$CURRENT_LINK" ]; then
    log "No symlink found at $LINKED_NODE_BINARY"
    exit 1
fi

# Get expected path for quilibrium user
EXPECTED_PATH="$QUIL_NODE_PATH"

# Check if current link points to wrong location
if [ "$CURRENT_LINK" != "$EXPECTED_PATH"* ]; then
    log "Symlink points to wrong location: $CURRENT_LINK"
    log "Expected location: $EXPECTED_PATH"

    # Get the binary filename
    BINARY_NAME=$(basename "$CURRENT_LINK")

    # Check if binary exists at current location
    if [ -f "$CURRENT_LINK" ]; then
        log "Binary found at old location: $CURRENT_LINK"

        # Ensure quilibrium directory exists
        QTOOLS_GROUP="qtools"
        sudo mkdir -p "$EXPECTED_PATH"
        sudo chown -R quilibrium:$QTOOLS_GROUP "$EXPECTED_PATH" 2>/dev/null || true
        # Ensure qtools group can read, write, and execute
        sudo chmod -R g+rwx "$EXPECTED_PATH" 2>/dev/null || true

        # Copy binary to new location
        NEW_BINARY_PATH="$EXPECTED_PATH/$BINARY_NAME"
        log "Copying binary to new location: $NEW_BINARY_PATH"
        sudo cp "$CURRENT_LINK" "$NEW_BINARY_PATH"
        sudo chown quilibrium:$QTOOLS_GROUP "$NEW_BINARY_PATH"
        sudo chmod g+rwx "$NEW_BINARY_PATH"
        sudo chmod +x "$NEW_BINARY_PATH"

        # Update symlink
        log "Updating symlink to point to: $NEW_BINARY_PATH"
        sudo ln -sf "$NEW_BINARY_PATH" "$LINKED_NODE_BINARY"

        log "Symlink fixed successfully!"
    else
        log "Binary not found at old location. Checking if it exists at new location..."
        if [ -f "$EXPECTED_PATH/$BINARY_NAME" ]; then
            log "Binary found at new location. Updating symlink..."
            sudo ln -sf "$EXPECTED_PATH/$BINARY_NAME" "$LINKED_NODE_BINARY"
            log "Symlink fixed successfully!"
        else
            log "Error: Binary not found at either location. Please download the node binary first."
            exit 1
        fi
    fi
else
    log "Symlink already points to correct location: $CURRENT_LINK"
fi

