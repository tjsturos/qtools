#!/bin/bash

if [ "$IS_LINKED" == "true" ]; then
    # if is linked, then start the secondary processes
    CORE_INDEX_START=$(yq e '.settings.linked_node.start_cpu_index' $QTOOLS_CONFIG_FILE)
    CORE_INDEX_STOP=$(yq e '.settings.linked_node.end_cpu_index' $QTOOLS_CONFIG_FILE)

    for ((i = $CORE_INDEX_START ; i <= $CORE_INDEX_STOP ; i++)); do
        systemctl stop $QUIL_SERVICE_NAME@$i.service
    done
else
    # otherwise just start the main process
    systemctl stop $QUIL_SERVICE_NAME@main.service
fi

pgrep -f node | grep -v $$ | xargs -r kill -9