#!/bin/bash

if [ "$IS_LINKED" != "true" ]; then
    # if is linked, then start the secondary processes
    # otherwise just start the main process
    sudo journalctl -u $QUIL_SERVICE_NAME@main -f --no-hostname -o cat
else
    CORE_INDEX_START=$(yq '.settings.linked_node.start_cpu_index' $QTOOLS_CONFIG_FILE)
    CORE_INDEX_STOP=$(yq '.settings.linked_node.end_cpu_index' $QTOOLS_CONFIG_FILE)

    for ((i = $CORE_INDEX_START ; i <= $CORE_INDEX_STOP ; i++)); do
        sudo journalctl -u $QUIL_SERVICE_NAME@$i -f --no-hostname -o cat
    done
fi