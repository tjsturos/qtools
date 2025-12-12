#!/bin/bash

# Exit on error
set -e

# Get current local_only value
CURRENT_VALUE=$(yq eval '.service.clustering.local_only' $QTOOLS_CONFIG_FILE)
MANUAL_STATE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --true)
            MANUAL_STATE="true"
            shift
            ;;
        --false)
            MANUAL_STATE="false"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

if [ -n "$MANUAL_STATE" ]; then
    NEW_VALUE="$MANUAL_STATE"
    qtools config set-value service.clustering.local_only "$NEW_VALUE" --quiet
    echo "Set local_only to $NEW_VALUE"
    exit 0
fi

# Toggle the value
if [ "$CURRENT_VALUE" = "true" ]; then
    NEW_VALUE="false"
else
    NEW_VALUE="true"
fi

# Update the config file
qtools config set-value service.clustering.local_only "$NEW_VALUE" --quiet

echo "Toggled local_only from $CURRENT_VALUE to $NEW_VALUE"
