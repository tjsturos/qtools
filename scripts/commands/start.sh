#!/bin/bash

# get settings
DEBUG_MODE="$(yq e '.settings.debug' $QTOOLS_CONFIG_FILE)"
IS_LINKED="$(yq e '.settings.linked_node.enabled' $QTOOLS_CONFIG_FILE)"

# make folder for args for each process
PROCESS_DIR=/tmp/quil-process-args
mkdir -p $PROCESS_DIR

NODE_ARGS="NODE_ARGS="

if [ "$DEBUG_MODE" == "true" ]; then
    NODE_ARGS="$NODE_ARGS--debug"
fi

# if is linked, we need to create a process for each process
if [ "$IS_LINKED" == "true" ]; then
    # if is linked, then start the secondary processes
    CORE_INDEX_START=$(yq e '.settings.linked_node.start_cpu_index' $QTOOLS_CONFIG_FILE)
    CORE_INDEX_STOP=$(yq e '.settings.linked_node.end_cpu_index' $QTOOLS_CONFIG_FILE)
    NODE_PROCESS_START=$(yq e '.settings.linked_node.process_index_offset' $QTOOLS_CONFIG_FILE)

    for ((i = $CORE_INDEX_START ; i <= $CORE_INDEX_STOP ; i++)); do
        INDEX=$(expr $i + $NODE_PROCESS_START)
        PORT=$(expr $INDEX + 40000)
        ufw allow $PORT
        NODE_ARGS="$NODE_ARGS --core=$INDEX" 
        echo $NODE_ARGS > $PROCESS_DIR/$i
        systemctl start $QUIL_SERVICE_NAME@$i.service
    done
else
    # otherwise just start the main process
    echo $NODE_ARGS > $PROCESS_DIR/main
    systemctl start $QUIL_SERVICE_NAME@main.service
fi