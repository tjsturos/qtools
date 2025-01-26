#!/bin/bash

# Set default priority for worker nodes to 90
DEFAULT_PRIORITY=90

# Check if a priority argument is provided, otherwise use default
PRIORITY=${1:-$DEFAULT_PRIORITY}

# Validate that priority is a number between 0 and 100
if ! [[ "$PRIORITY" =~ ^[0-9]+$ ]] || [ "$PRIORITY" -lt 0 ] || [ "$PRIORITY" -gt 100 ]; then
    echo "Error: Priority must be a number between 0 and 100"
    exit 1
fi

# Update the config file with the new priority
yq -i ".service.dataworker_priority = $PRIORITY" $QTOOLS_CONFIG_FILE

# Run the update-service script to apply changes
qtools update-service

echo "Successfully set data worker priority to $PRIORITY"
