#!/bin/bash

# Read the current configuration
CONFIG=$(yq eval . $QTOOLS_CONFIG_FILE)
# Get current state of connection checks
CURRENT_STATE=$(echo "$CONFIG" | yq eval '.scheduled_tasks.cluster.auto_reconnect.enabled // "false"' -)

if [ "$(yq eval '.qtools_version' $QTOOLS_CONFIG_FILE)" != "17" ]; then
    qtools migrate-qtools-config
fi

# Initialize NEW_STATE to handle direct setting rather than toggling
NEW_STATE=$([ "$CURRENT_STATE" = "true" ] && echo "false" || echo "true")

# Check for --on or --off flags
while [[ $# -gt 0 ]]; do
    case $1 in
        --on)
            if [ "$CURRENT_STATE" = "true" ]; then
                echo "Connection checks are already enabled"
                exit 0
            fi
            NEW_STATE="true"
            shift
            ;;
        --off)
            if [ "$CURRENT_STATE" = "false" ]; then
                echo "Connection checks are already disabled"
                exit 0
            fi
            NEW_STATE="false"
            shift
            ;;
        *)
            echo "Invalid option: $1"
            echo "Usage: $0 [--on|--off]"
            exit 1
            ;;
    esac
done

# Check if clustering is enabled
if [ "$IS_CLUSTERING_ENABLED" != "true" ]; then
    echo "Clustering is not enabled. This feature is for clusters only."
    NEW_STATE="false"
fi

# Output status message based on the new state
if [ "$NEW_STATE" = "true" ]; then
    echo "Enabling cluster connection checks..."
else
    echo "Disabling cluster connection checks..."
fi

# Update the configuration
yq eval -i ".scheduled_tasks.cluster.auto_reconnect.enabled = $NEW_STATE" $QTOOLS_CONFIG_FILE

echo "Cluster connection checks are now $([ "$NEW_STATE" = "true" ] && echo "enabled" || echo "disabled")"
qtools update-cron

