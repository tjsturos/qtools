#!/bin/bash
# HELP: Adds one or more peer IDs to the config carousel list
# PARAM: <peer_id...>: One or more Qm... peer IDs to add to the carousel
# Usage: qtools add-to-carousel <peer_id> [peer_id...]

# Check if config needs migration
if ! yq eval '.scheduled_tasks.config_carousel' $QTOOLS_CONFIG_FILE >/dev/null 2>&1; then
    echo "Config needs migration. Running migration..."
    qtools migrate-qtools-config
fi

# Validate input
if [ $# -lt 1 ]; then
    echo "Error: Please provide at least one peer ID"
    echo "Usage: qtools add-to-carousel <peer_id> [peer_id...]"
    exit 1
fi

add_peer() {
    local PEER_ID="$1"
    
    # Validate peer ID format (starts with Qm)
    if [[ ! $PEER_ID =~ ^Qm ]]; then
        echo "Skipping invalid peer ID format (must start with 'Qm'): $PEER_ID"
        return 0
    fi

    # Check if peer ID already exists in the list
    if yq eval ".scheduled_tasks.config_carousel.peer_list[] | select(. == \"$PEER_ID\")" $QTOOLS_CONFIG_FILE | grep -q .; then
        echo "Peer ID already exists in carousel: $PEER_ID"
        return 0
    fi

    # Check if peer config exists locally
    if [ ! -d "$QUIL_NODE_PATH/$PEER_ID" ]; then
        echo "Peer configuration not found locally. Downloading: $PEER_ID"
        if ! qtools restore-peer "$PEER_ID"; then
            echo "Failed to download peer configuration, skipping: $PEER_ID"
            return 0
        fi
        echo "Creating local backup: $PEER_ID"
        if ! qtools backup-peer --local "$PEER_ID"; then
            echo "Failed to create local backup, skipping: $PEER_ID"
            return 0
        fi
    fi

    # Add peer ID to the list
    yq eval -i ".scheduled_tasks.config_carousel.peer_list += [\"$PEER_ID\"]" $QTOOLS_CONFIG_FILE

    echo "Added peer ID to carousel: $PEER_ID"
    return 0
}

# Process each peer ID
for peer in "$@"; do
    add_peer "$peer"
done 