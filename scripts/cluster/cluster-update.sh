#!/bin/bash
IS_MASTER=false
# Check if --master option is passed
if [[ "$*" == *"--master"* ]]; then
   IS_MASTER=true
fi

# Main script execution
qtools update-node

if [ "$IS_MASTER" == "true" ] || [ "$(is_master)" == "true" ]; then
    ssh_command_to_each_server "qtools update-node"
fi



