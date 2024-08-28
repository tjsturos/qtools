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


# make folder for args for each process
PROCESS_DIR=/tmp/quil-process-args
mkdir -p $PROCESS_DIR

NODE_ARGS="NODE_ARGS="

if [ "$DEBUG_MODE" == "true" ]; then
    NODE_ARGS="$NODE_ARGS--debug"
fi

echo $NODE_ARGS > $PROCESS_DIR/main
sudo systemctl start $QUIL_SERVICE_NAME.service
