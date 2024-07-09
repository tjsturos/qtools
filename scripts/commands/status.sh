#!/bin/bash
# HELP: Gets the node application service\'s current status.
# Usage: qtools status

if [ "$IS_LINKED" == "true" ]; then
    # if is linked, then start the secondary processes
    CORE_INDEX_START=$(yq '.settings.linked_node.start_cpu_index' $QTOOLS_CONFIG_FILE)
    CORE_INDEX_STOP=$(yq '.settings.linked_node.end_cpu_index' $QTOOLS_CONFIG_FILE)

    for ((i = $CORE_INDEX_START ; i <= $CORE_INDEX_STOP ; i++)); do
        sudo systemctl status $QUIL_SERVICE_NAME@$i.service
    done
else
    # otherwise just start the main process
    sudo systemctl status $QUIL_SERVICE_NAME@main.service
fi