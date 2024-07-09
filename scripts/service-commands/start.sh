#!/bin/bash
# HELP: Starts the node application service. If .settings.debug is set to true or use --debug flag, this will start node in debug mode.
# PARAM: --debug: will start the node application in debug mode
# Usage: qtools start
# Usage: qtools start --debug

# get settings
DEBUG_MODE="$(yq '.settings.debug' $QTOOLS_CONFIG_FILE)"

if [ "$1" == "--debug" ]; then
    DEBUG_MODE="true"
fi

IS_LINKED="$(yq '.settings.linked_node.enabled' $QTOOLS_CONFIG_FILE)"

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
    CORE_INDEX_START=$(yq '.settings.linked_node.start_cpu_index' $QTOOLS_CONFIG_FILE)
    CORE_INDEX_STOP=$(yq '.settings.linked_node.end_cpu_index' $QTOOLS_CONFIG_FILE)
    NODE_PROCESS_START=$(yq '.settings.linked_node.process_index_offset' $QTOOLS_CONFIG_FILE)

    for ((i = $CORE_INDEX_START ; i <= $CORE_INDEX_STOP ; i++)); do
        INDEX=$(expr $i + $NODE_PROCESS_START)
        PORT=$(expr $INDEX + 40000)
        sudo ufw allow $PORT
        NODE_ARGS="$NODE_ARGS --core=$INDEX" 
        echo $NODE_ARGS > $PROCESS_DIR/$i
        sudo systemctl start $QUIL_SERVICE_NAME@$i.service
    done
else
    # otherwise just start the main process
    echo $NODE_ARGS > $PROCESS_DIR/main
    sudo systemctl start $QUIL_SERVICE_NAME@main.service
fi