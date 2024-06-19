#!/bin/bash

if [ "$IS_LINKED" == "true" ]; then
    # if is linked, then start the secondary processes
    CORE_INDEX_START=$(yq '.settings.linked_node.start_cpu_index' $QTOOLS_CONFIG_FILE)
    CORE_INDEX_STOP=$(yq '.settings.linked_node.end_cpu_index' $QTOOLS_CONFIG_FILE)
    NODE_PROCESS_START=$(yq '.settings.linked_node.process_start_index' $QTOOLS_CONFIG_FILE)

    for ((i = $CORE_INDEX_START ; i <= $CORE_INDEX_STOP ; i++)); do
        NODE_ARGS="$NODE_ARGS --core=$(expr $i)" 
        systemctl restart $QUIL_SERVICE_NAME@$i.service
    done
else
    # otherwise just start the main process
    systemctl restart $QUIL_SERVICE_NAME@main.service
fi