#!/bin/bash
# HELP: Enables the node application service, allowing it to start on system boot. Note: this does not start the node service immediately.

# Usage: qtools enable

if [ "$IS_LINKED" == "true" ]; then
    # if is linked, then start the secondary processes
    CORE_INDEX_START=$(yq '.settings.linked_node.start_cpu_index' $QTOOLS_CONFIG_FILE)
    CORE_INDEX_STOP=$(yq '.settings.linked_node.end_cpu_index' $QTOOLS_CONFIG_FILE)
    NODE_PROCESS_START=$(yq '.settings.linked_node.process_start_index' $QTOOLS_CONFIG_FILE)

    for ((i = $CORE_INDEX_START ; i <= $CORE_INDEX_STOP ; i++)); do
        NODE_ARGS="$NODE_ARGS --core=$(expr $i)" 
        sudo systemctl enable $QUIL_SERVICE_NAME@$i.service
    done
else
    # otherwise just start the main process
    sudo systemctl enable $QUIL_SERVICE_NAME@main.service
fi
