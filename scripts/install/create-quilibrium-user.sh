#!/bin/bash
# HELP: Creates and configures the 'quilibrium' system user for running node services.
# USAGE: qtools create-quilibrium-user

QUILIBRIUM_USER="quilibrium"
QUILIBRIUM_HOME="/home/$QUILIBRIUM_USER"
QUILIBRIUM_NODE_PATH="$QUILIBRIUM_HOME/ceremonyclient/node"
CEREMONYCLIENT_PATH="$QUILIBRIUM_HOME/ceremonyclient"

log "Creating quilibrium system user..."

# Create qtools group if it doesn't exist
if ! getent group "$QTOOLS_GROUP" >/dev/null 2>&1; then
    log "Creating qtools group..."
    sudo groupadd "$QTOOLS_GROUP"
    if [ $? -eq 0 ]; then
        log "Group '$QTOOLS_GROUP' created successfully."
    else
        log "Failed to create group '$QTOOLS_GROUP'."
        exit 1
    fi
else
    log "Group '$QTOOLS_GROUP' already exists."
fi

# Check if user already exists
if id "$QUILIBRIUM_USER" &>/dev/null; then
    log "User '$QUILIBRIUM_USER' already exists. Skipping user creation."
else
    # Create system user with no login shell
    log "Creating system user '$QUILIBRIUM_USER'..."
    sudo useradd -r -s /usr/sbin/nologin -d "$QUILIBRIUM_HOME" -m "$QUILIBRIUM_USER"

    if [ $? -eq 0 ]; then
        log "User '$QUILIBRIUM_USER' created successfully."
    else
        log "Failed to create user '$QUILIBRIUM_USER'."
        exit 1
    fi
fi

# Ensure quilibrium user is in qtools group
if ! id -Gn "$QUILIBRIUM_USER" 2>/dev/null | grep -q "\b$QTOOLS_GROUP\b"; then
    log "Adding quilibrium user to qtools group..."
    sudo usermod -a -G "$QTOOLS_GROUP" "$QUILIBRIUM_USER"
fi

# Ensure root is in qtools group
if ! id -Gn root 2>/dev/null | grep -q "\b$QTOOLS_GROUP\b"; then
    log "Adding root user to qtools group..."
    sudo usermod -a -G "$QTOOLS_GROUP" root
fi

# Add all existing system users (regular users with UID >= 1000) to qtools group
log "Adding all existing system users to qtools group..."
SYSTEM_USERS=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print $1}')
for user in $SYSTEM_USERS; do
    # Skip quilibrium and root as we already added them
    if [ "$user" != "$QUILIBRIUM_USER" ] && [ "$user" != "root" ]; then
        if ! id -Gn "$user" 2>/dev/null | grep -q "\b$QTOOLS_GROUP\b"; then
            log "Adding user '$user' to qtools group..."
            sudo usermod -a -G "$QTOOLS_GROUP" "$user" 2>/dev/null || log "Warning: Failed to add user '$user' to qtools group."
        fi
    fi
done

# Create directory structure for quilibrium user
log "Setting up directory structure for quilibrium user..."
sudo mkdir -p "$QUILIBRIUM_NODE_PATH/.config"
sudo mkdir -p "$QUILIBRIUM_HOME/ceremonyclient/client"

# Set ownership of quilibrium user's directories to quilibrium:qtools
sudo chown -R "$QUILIBRIUM_USER:$QTOOLS_GROUP" "$QUILIBRIUM_HOME"

# Set permissions on ceremonyclient directory so qtools group members can edit/view/execute
log "Setting permissions on ceremonyclient directory..."
sudo chmod -R g+rwx "$CEREMONYCLIENT_PATH" 2>/dev/null || true

# Also ensure parent directories have proper permissions
sudo chmod g+rx "$QUILIBRIUM_HOME" 2>/dev/null || true

# Check if there's an existing node installation in the current user's directory
# If so, give quilibrium user access to it (for backward compatibility)
CURRENT_USER_HOME=$(eval echo ~$(whoami))
EXISTING_NODE_PATH="$CURRENT_USER_HOME/ceremonyclient/node"

if [ -d "$EXISTING_NODE_PATH" ] && [ "$EXISTING_NODE_PATH" != "$QUILIBRIUM_NODE_PATH" ]; then
    log "Found existing node installation at $EXISTING_NODE_PATH"
    log "Granting quilibrium user access to existing node directory..."

    # Add quilibrium user to a group that has access, or use ACLs
    # For simplicity, we'll add read/execute permissions for the quilibrium user
    # The service will use quilibrium's home directory, but this allows access to binaries if needed

    # Ensure quilibrium can read the directory structure
    sudo setfacl -R -m u:$QUILIBRIUM_USER:rx "$EXISTING_NODE_PATH" 2>/dev/null || {
        # If setfacl is not available, use chmod to add group read permissions
        # Add quilibrium to the current user's group temporarily for access
        CURRENT_GROUP=$(id -gn)
        sudo usermod -a -G "$CURRENT_GROUP" "$QUILIBRIUM_USER" 2>/dev/null || true
        sudo chmod -R o+rx "$EXISTING_NODE_PATH" 2>/dev/null || true
    }
fi

# Ensure quilibrium user can access the node binary location
# The node binary is symlinked to /usr/local/bin/node, which should be accessible to all users
# But we need to ensure quilibrium can execute it
if [ -L "/usr/local/bin/node" ] || [ -f "/usr/local/bin/node" ]; then
    # Ensure the binary is executable by all users (should already be the case)
    sudo chmod +x /usr/local/bin/node 2>/dev/null || true
    # Also ensure the actual binary file is executable
    REAL_BINARY=$(readlink -f /usr/local/bin/node 2>/dev/null || echo "")
    if [ -n "$REAL_BINARY" ] && [ -f "$REAL_BINARY" ]; then
        sudo chmod +x "$REAL_BINARY" 2>/dev/null || true
        # Give quilibrium user read/execute access to the binary
        sudo setfacl -m u:$QUILIBRIUM_USER:rx "$REAL_BINARY" 2>/dev/null || true
    fi
fi

log "Quilibrium user setup complete."
log "Home directory: $QUILIBRIUM_HOME"
log "Node path: $QUILIBRIUM_NODE_PATH"
log "Qtools group: $QTOOLS_GROUP"
log "Note: You may need to log out and log back in for group changes to take effect."

