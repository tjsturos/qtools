#!/bin/bash
# HELP: Get and display all direct peers from the node's config file

# Check if QUIL config file exists (handle quilibrium-owned files)
if ! safe_file_exists "$QUIL_CONFIG_FILE"; then
    echo "Error: QUIL config file not found at $QUIL_CONFIG_FILE"
    exit 1
fi

# Check if file is owned by quilibrium user and use sudo if needed
file_owner=$(stat -c '%U' "$QUIL_CONFIG_FILE" 2>/dev/null || sudo stat -c '%U' "$QUIL_CONFIG_FILE" 2>/dev/null || stat -f '%Su' "$QUIL_CONFIG_FILE" 2>/dev/null || echo "")
use_sudo=false
if [ "$file_owner" == "quilibrium" ] && [ "$(whoami)" != "root" ]; then
    use_sudo=true
fi

# Get direct peers from config
if [ "$use_sudo" == "true" ]; then
    DIRECT_PEERS=$(sudo yq eval '.p2p.directPeers[]' "$QUIL_CONFIG_FILE" 2>/dev/null)
    PEER_COUNT=$(sudo yq eval '.p2p.directPeers | length' "$QUIL_CONFIG_FILE" 2>/dev/null || echo "0")
else
    DIRECT_PEERS=$(yq eval '.p2p.directPeers[]' "$QUIL_CONFIG_FILE" 2>/dev/null)
    PEER_COUNT=$(yq eval '.p2p.directPeers | length' "$QUIL_CONFIG_FILE" 2>/dev/null || echo "0")
fi

# Display results
if [ "$PEER_COUNT" == "0" ] || [ -z "$DIRECT_PEERS" ]; then
    echo "No direct peers configured."
    exit 0
fi

echo "Direct peers ($PEER_COUNT):"
echo ""

# Display each peer on a separate line
while IFS= read -r peer; do
    # Skip empty lines
    [[ -z "$peer" ]] && continue
    echo "  $peer"
done <<< "$DIRECT_PEERS"
