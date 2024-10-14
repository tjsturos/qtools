#!/bin/bash

# Check if the correct number of arguments are provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <new_url>"
    exit 1
fi
log "Changing backup URL to $1"
yq eval -i ".scheduled_tasks.backup.backup_url = \"$1\"" $QTOOLS_CONFIG_FILE

