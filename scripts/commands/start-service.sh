#!/bin/bash

# start the main process
DEBUG_MODE="$(yq e '.settings.debug' $QTOOLS_CONFIG_FILE)"
PROCESS_DIR=/tmp/quil-process-args

mkdir -p $PROCESS_DIR

if [ "$DEBUG_MODE" == "true" ]; then
    echo "NODE_ARGS=\"--debug\"" > $PROCESS_DIR/main
fi

systemctl start $QUIL_SERVICE_NAME@main.service

IS_LINKED="$(yq e '.settings.slave' $QTOOLS_CONFIG_FILE)"
if [ "$IS_LINKED" == "true" ]; then
    MAIN_PID="$(systemctl status $QUIL_SERVICE_NAME | grep 'Main PID' | awk '{print $3}')"
    # if is linked, then start the secondary processes
    CORE_COUNT=$(get_processor_count)
    log Node parent ID: $MAIN_PID;

    for I in {1..$CORE_COUNT}; do
        echo "NODE_ARGS=\"--core=$(expr $I) --parent-process=$NODE_PID\"" > $PROCESS_DIR/$I
        systemctl start $QUIL_SERVICE_NAME@$I.service
    done
fi
