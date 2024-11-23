#!/bin/bash
# HELP: Set the maximum frame number for the node
# PARAM: <frame_number>: The maximum frame number to set, or 'default' to remove the setting

FRAME_NUMBER="$1"

if [ -z "$FRAME_NUMBER" ]; then
    echo "Error: Frame number argument is required"
    exit 1
fi

if [ "$FRAME_NUMBER" = "default" ]; then
    # Delete the maxFrame property if set to default
    yq eval 'del(.engine.maxFrame)' -i $QUIL_CONFIG_FILE
    echo "Removed max frame setting"
else
    # Validate frame number is an integer
    if ! [[ "$FRAME_NUMBER" =~ ^[0-9]+$ ]]; then
        echo "Error: Frame number must be a positive integer"
        exit 1
    fi
    
    # Set the maxFrame value
    yq eval ".engine.maxFrame = $FRAME_NUMBER" -i $QUIL_CONFIG_FILE
    echo "Set max frame to $FRAME_NUMBER"
fi

