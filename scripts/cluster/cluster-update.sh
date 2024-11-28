#!/bin/bash
IS_MASTER=false
DRY_RUN=false
UPDATE_QTOOLS=false

# Check if --master option is passed
if [[ "$*" == *"--master"* ]]; then
   IS_MASTER=true
fi

# Check if --dry-run option is passed
if [[ "$*" == *"--dry-run"* ]]; then
   DRY_RUN=true
fi

# Check if --update-qtools option is passed
if [[ "$*" == *"--update-qtools"* ]]; then
   UPDATE_QTOOLS=true
fi

# Main script execution
qtools self-update
qtools update-node

if [ "$IS_MASTER" == "true" ] || [ "$(is_master)" == "true" ]; then
    if [ "$UPDATE_QTOOLS" == "true" ]; then
        ssh_command_to_each_server "qtools self-update"
    fi

    ssh_command_to_each_server "qtools download-node --link"
fi



