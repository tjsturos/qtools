#!/bin/bash
IS_MASTER=false
DRY_RUN=false

# Check if --master option is passed
if [[ "$*" == *"--master"* ]]; then
   IS_MASTER=true
fi

# Check if --dry-run option is passed
if [[ "$*" == *"--dry-run"* ]]; then
   DRY_RUN=true
fi

# Main script execution
qtools update-node

if [ "$IS_MASTER" == "true" ] || [ "$(is_master)" == "true" ]; then
    ssh_command_to_each_server "qtools update-node"
fi



