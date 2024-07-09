#!/bin/bash
# HELP: Stops the node application service. Will also clean up any leftover node processes (if any).
# Usage: qtools stop

if [ "$IS_LINKED" == "true" ]; then
    # if is linked, then start the secondary processes
    CORE_INDEX_START=$(yq '.settings.linked_node.start_cpu_index' $QTOOLS_CONFIG_FILE)
    CORE_INDEX_STOP=$(yq '.settings.linked_node.end_cpu_index' $QTOOLS_CONFIG_FILE)

    for ((i = $CORE_INDEX_START ; i <= $CORE_INDEX_STOP ; i++)); do
        sudo systemctl stop $QUIL_SERVICE_NAME@$i.service
    done
else
    # otherwise just start the main process
    sudo systemctl stop $QUIL_SERVICE_NAME@main.service
fi

pgrep -f node | grep -v $$ | xargs -r sudo kill -9