#!/bin/bash

# HELP: Views the logs for the node application.
# Get the log file path from the launchd plist
LOG_FILE=$(launchctl list | grep "$QUIL_SERVICE_NAME" | awk '{print $3}' | xargs launchctl list -x | grep StandardOutPath | awk -F '<string>' '{print $2}' | awk -F '</string>' '{print $1}')

if [ -z "$LOG_FILE" ]; then
    echo "Error: Unable to find log file for $QUIL_SERVICE_NAME"
    exit 1
fi

# Use tail to follow the log file
tail -f "$LOG_FILE"

