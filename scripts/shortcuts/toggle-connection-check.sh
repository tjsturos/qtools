#!/bin/bash

# Read the current configuration
CONFIG=$(yq eval . $QTOOLS_CONFIG_FILE)

# Get current state of connection checks
CURRENT_STATE=$(echo "$CONFIG" | yq eval '.scheduled_tasks.cluster.auto_reconnect.enabled // "false"' -)

# Check for --on or --off flags
while [[ $# -gt 0 ]]; do
    case $1 in
        --on)
            CURRENT_STATE="false" # Setting to false so it will be toggled to true
            shift
            ;;
        --off)
            CURRENT_STATE="true" # Setting to true so it will be toggled to false
            shift
            ;;
        *)
            echo "Invalid option: $1"
            echo "Usage: $0 [--on|--off]"
            exit 1
            ;;
    esac
done


# Toggle the state
if [ "$CURRENT_STATE" = "true" ]; then
    NEW_STATE="false"
    echo "Enabling cluster connection checks..."
else
    NEW_STATE="true" 
    echo "Disabling cluster connection checks..."
fi

# Update the configuration
yq eval -i ".scheduled_tasks.cluster.auto_reconnect.enabled = $NEW_STATE" $QTOOLS_CONFIG_FILE

echo "Cluster connection checks are now $([ "$NEW_STATE" = "true" ] && echo "disabled" || echo "enabled")"
qtools update-cron

