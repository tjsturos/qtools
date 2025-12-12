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
file_accessible_without_sudo=false
if [ -f "$QUIL_CONFIG_FILE" ]; then
    file_accessible_without_sudo=true
elif sudo test -f "$QUIL_CONFIG_FILE" 2>/dev/null; then
    # File exists but only accessible with sudo
    file_accessible_without_sudo=false
else
    echo "Error: Config file not found at $QUIL_CONFIG_FILE"
    exit 1
fi

# Check if file is owned by quilibrium user and use sudo if needed
# This handles cases where user was just added to quilibrium group
# but current shell session doesn't have group membership active yet
file_owner=""
# Try regular stat first
if [ "$file_accessible_without_sudo" == "true" ]; then
    file_owner=$(stat -c '%U' "$QUIL_CONFIG_FILE" 2>/dev/null || echo "")
fi
# If that failed or returned empty, try with sudo
if [ -z "$file_owner" ]; then
    file_owner=$(sudo stat -c '%U' "$QUIL_CONFIG_FILE" 2>/dev/null || echo "")
fi
# Fallback for macOS/BSD systems
if [ -z "$file_owner" ]; then
    if [ "$file_accessible_without_sudo" == "true" ]; then
        file_owner=$(stat -f '%Su' "$QUIL_CONFIG_FILE" 2>/dev/null || echo "")
    fi
    if [ -z "$file_owner" ]; then
        file_owner=$(sudo stat -f '%Su' "$QUIL_CONFIG_FILE" 2>/dev/null || echo "")
    fi
fi

use_sudo=false
# Use sudo if file is owned by quilibrium and we're not root
if [ "$file_owner" == "quilibrium" ] && [ "$(whoami)" != "root" ]; then
    use_sudo=true
fi
# Also use sudo if file is not accessible without sudo
if [ "$file_accessible_without_sudo" == "false" ] && [ "$(whoami)" != "root" ]; then
    use_sudo=true
fi

# Helper function to run yq with appropriate permissions
run_yq() {
    local yq_command="$1"
    if [ "$use_sudo" == "true" ]; then
        if ! sudo yq -i "$yq_command" "$QUIL_CONFIG_FILE" 2>&1 >/dev/null; then
            return 1
        fi
    else
        # Try without sudo first, capturing any error output
        local error_output
        error_output=$(yq -i "$yq_command" "$QUIL_CONFIG_FILE" 2>&1)
        local exit_code=$?
        if [ $exit_code -ne 0 ]; then
            # If it failed, check if it was a permission error and retry with sudo
            if echo "$error_output" | grep -qi "permission denied"; then
                # Permission error, try with sudo
                if sudo yq -i "$yq_command" "$QUIL_CONFIG_FILE" 2>&1 >/dev/null; then
                    # Success with sudo, update use_sudo for future operations
                    use_sudo=true
                else
                    echo "$error_output" >&2
                    return 1
                fi
            else
                # Some other error, show it and return failure
                echo "$error_output" >&2
                return 1
            fi
        fi
    fi
    return 0
}

# Handle clearing the delegate address
if [ "$PEER_ID" == "clear" ]; then
    if ! run_yq 'del(.engine.delegateAddress)'; then
        echo "Error: Failed to clear delegate address. Permission denied."
        exit 1
    fi
    echo "Reward peer ID (delegateAddress) cleared from config"
    qtools --describe "set-reward-peer-id" restart
    exit 0
fi

# Validate peer ID format (should start with Qm or 12D3KooW)
if ! [[ "$PEER_ID" =~ ^(Qm|12D3KooW) ]]; then
    echo "Error: Invalid peer ID format. Expected to start with 'Qm' or '12D3KooW', got: $PEER_ID"
    exit 1
fi

# Set the delegate address
if ! run_yq ".engine.delegateAddress = \"$PEER_ID\""; then
    echo "Error: Failed to set delegate address. Permission denied."
    exit 1
fi

echo "Reward peer ID (delegateAddress) set to: $PEER_ID"

qtools --describe "set-reward-peer-id" restart
