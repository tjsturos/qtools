#!/bin/bash
# HELP: Toggle the skip_192_168_block setting to control whether the 192.168.0.0/16 outbound block is added in firewall setup

# Exit on error
set -e

# Get current skip_192_168_block value
CURRENT_VALUE=$(yq eval '.ssh.skip_192_168_block // false' $QTOOLS_CONFIG_FILE)
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
    yq eval -i ".ssh.skip_192_168_block = $NEW_VALUE" $QTOOLS_CONFIG_FILE
    echo "Set skip_192_168_block to $NEW_VALUE"
    exit 0
fi

# Toggle the value
if [ "$CURRENT_VALUE" = "true" ]; then
    NEW_VALUE="false"
else
    NEW_VALUE="true"
fi

# Update the config file
yq eval -i ".ssh.skip_192_168_block = $NEW_VALUE" $QTOOLS_CONFIG_FILE

echo "Toggled skip_192_168_block from $CURRENT_VALUE to $NEW_VALUE"

