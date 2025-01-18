#!/bin/bash
# HELP: Adds a peer ID to the config carousel list
# PARAM: <peer_id>: The Qm... peer ID to add to the carousel
# Usage: qtools add-to-carousel <peer_id>

# Check if config needs migration
if ! yq eval '.scheduled_tasks.config_carousel' $QTOOLS_CONFIG_FILE >/dev/null 2>&1; then
    echo "Config needs migration. Running migration..."
    qtools migrate-qtools-config
fi

# Validate input
if [ $# -ne 1 ]; then
    echo "Error: Please provide exactly one peer ID"
    echo "Usage: qtools add-to-carousel <peer_id>"
    exit 1
fi

PEER_ID="$1"

# Validate peer ID format (starts with Qm)
if [[ ! $PEER_ID =~ ^Qm ]]; then
    echo "Error: Invalid peer ID format. Must start with 'Qm'"
    exit 1
fi

# Check if peer ID already exists in the list
if yq eval ".scheduled_tasks.config_carousel.peer_list[] | select(. == \"$PEER_ID\")" $QTOOLS_CONFIG_FILE | grep -q .; then
    echo "Peer ID already exists in carousel"
    exit 0
fi

# Add peer ID to the list
yq eval -i ".scheduled_tasks.config_carousel.peer_list += [\"$PEER_ID\"]" $QTOOLS_CONFIG_FILE

echo "Added peer ID to carousel: $PEER_ID" 