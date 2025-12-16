#!/bin/bash
# HELP: Creates or updates the node binary symlink. By default, links to the latest binary in QUIL_NODE_PATH.
# PARAM: --path <path>: Override to link to a specific binary path
# USAGE: qtools create-node-symlink
# USAGE: qtools create-node-symlink --path /path/to/node-binary

# Parse command line arguments
CUSTOM_BINARY_PATH=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --path)
            CUSTOM_BINARY_PATH="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: qtools create-node-symlink [--path <path>]"
            exit 1
            ;;
    esac
done

log "Creating/updating node binary symlink..."

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

# Function to find the latest node binary in a directory
find_latest_binary() {
    local search_dir="$1"
    if [ ! -d "$search_dir" ]; then
        return 1
    fi

    # Find all node binaries matching the pattern node-*-$OS_ARCH (with or without -avx512 suffix)
    # Sort by version number (extracted from filename) in descending order
    local latest_binary=$(find "$search_dir" -maxdepth 1 -type f \( -name "node-*-${OS_ARCH}" -o -name "node-*-${OS_ARCH}-avx512" \) 2>/dev/null | \
        sort -V -r | head -n 1)

    if [ -n "$latest_binary" ] && [ -f "$latest_binary" ]; then
        echo "$latest_binary"
        return 0
    fi

    return 1
}

# Determine the target binary path
TARGET_BINARY=""

if [ -n "$CUSTOM_BINARY_PATH" ]; then
    # Use custom path if provided
    if [ ! -f "$CUSTOM_BINARY_PATH" ]; then
        log "Error: Binary not found at custom path: $CUSTOM_BINARY_PATH"
        exit 1
    fi
    TARGET_BINARY="$CUSTOM_BINARY_PATH"
    log "Using custom binary path: $TARGET_BINARY"
else
    # Find latest binary in QUIL_NODE_PATH
    if ! TARGET_BINARY=$(find_latest_binary "$QUIL_NODE_PATH"); then
        log "Error: No node binary found in $QUIL_NODE_PATH"
        log "Please download a node binary first using 'qtools download-node'"
        exit 1
    fi
    log "Found latest binary: $TARGET_BINARY"
fi

# Ensure the binary has correct permissions
if [ "$SERVICE_USER" == "quilibrium" ] && id "quilibrium" &>/dev/null; then
    sudo chown quilibrium:$QTOOLS_GROUP "$TARGET_BINARY" 2>/dev/null || true
    sudo chmod g+rwx "$TARGET_BINARY" 2>/dev/null || true
    sudo chmod +x "$TARGET_BINARY" 2>/dev/null || true
fi

# Check if symlink already exists and points to the correct location
CURRENT_LINK=$(readlink -f "$LINKED_NODE_BINARY" 2>/dev/null || echo "")

if [ -n "$CURRENT_LINK" ] && [ "$CURRENT_LINK" == "$TARGET_BINARY" ]; then
    log "Symlink already points to the correct location: $TARGET_BINARY"
    exit 0
fi

# Create or update the symlink
if [ -L "$LINKED_NODE_BINARY" ]; then
    log "Updating existing symlink..."
else
    log "Creating new symlink..."
fi

sudo ln -sf "$TARGET_BINARY" "$LINKED_NODE_BINARY"

# Verify the symlink was created correctly
VERIFIED_LINK=$(readlink -f "$LINKED_NODE_BINARY" 2>/dev/null || echo "")
if [ "$VERIFIED_LINK" == "$TARGET_BINARY" ]; then
    log "Successfully created/updated symlink: $LINKED_NODE_BINARY -> $TARGET_BINARY"

    # Extract version from binary name and persist to config
    VERSION_FROM_BINARY=$(basename "$TARGET_BINARY" | grep -oP "node-\K([0-9]+\.?)+" || echo "")
    if [ -n "$VERSION_FROM_BINARY" ]; then
        set_current_node_version "$VERSION_FROM_BINARY" 2>/dev/null || true
    fi
else
    log "Error: Failed to create/update symlink. Expected: $TARGET_BINARY, Got: $VERIFIED_LINK"
    exit 1
fi
