#!/bin/bash
# HELP: Sets the reward peer ID (delegateAddress) in the node config
# PARAM: <peer-id>: The peer ID to set as the reward delegate, or "clear" to remove it
# Usage: qtools set-reward-peer-id <peer-id>
# Usage: qtools set-reward-peer-id clear

if [ $# -ne 1 ]; then
    echo "Usage: qtools set-reward-peer-id <peer-id>"
    echo "       qtools set-reward-peer-id clear"
    echo ""
    echo "Examples:"
    echo "  qtools set-reward-peer-id QmXxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    echo "  qtools set-reward-peer-id 12D3KooWxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    echo "  qtools set-reward-peer-id clear"
    exit 1
fi

PEER_ID="$1"

# Check if config file exists (handle quilibrium-owned files)
# Try normal check first, then with sudo if needed
if [ ! -f "$QUIL_CONFIG_FILE" ]; then
    # File might exist but be owned by quilibrium user
    # Check with sudo if normal check failed
    if ! sudo test -f "$QUIL_CONFIG_FILE" 2>/dev/null; then
        echo "Error: Config file not found at $QUIL_CONFIG_FILE"
        exit 1
    fi
fi

# Check if file is owned by quilibrium user and use sudo if needed
# This handles cases where user was just added to quilibrium group
# but current shell session doesn't have group membership active yet
file_owner=$(stat -c '%U' "$QUIL_CONFIG_FILE" 2>/dev/null || sudo stat -c '%U' "$QUIL_CONFIG_FILE" 2>/dev/null || stat -f '%Su' "$QUIL_CONFIG_FILE" 2>/dev/null || echo "")
use_sudo=false
if [ "$file_owner" == "quilibrium" ] && [ "$(whoami)" != "root" ]; then
    use_sudo=true
fi

# Handle clearing the delegate address
if [ "$PEER_ID" == "clear" ]; then
    if [ "$use_sudo" == "true" ]; then
        sudo yq -i 'del(.engine.delegateAddress)' $QUIL_CONFIG_FILE
    else
        yq -i 'del(.engine.delegateAddress)' $QUIL_CONFIG_FILE
    fi
    echo "Reward peer ID (delegateAddress) cleared from config"
    qtools restart
    exit 0
fi

# Validate peer ID format (should start with Qm or 12D3KooW)
if ! [[ "$PEER_ID" =~ ^(Qm|12D3KooW) ]]; then
    echo "Error: Invalid peer ID format. Expected to start with 'Qm' or '12D3KooW', got: $PEER_ID"
    exit 1
fi

# Set the delegate address
if [ "$use_sudo" == "true" ]; then
    sudo yq -i ".engine.delegateAddress = \"$PEER_ID\"" $QUIL_CONFIG_FILE
else
    yq -i ".engine.delegateAddress = \"$PEER_ID\"" $QUIL_CONFIG_FILE
fi

echo "Reward peer ID (delegateAddress) set to: $PEER_ID"

qtools restart
