#!/bin/bash

# start the main process
DEBUG_MODE="$(yq e '.settings.debug' $QTOOLS_CONFIG_FILE)"
PROCESS_DIR=/tmp/quil-process-args

mkdir -p $PROCESS_DIR

if [ "$DEBUG_MODE" == "true" ]; then
    echo "NODE_ARGS=\"--debug\"" > $PROCESS_DIR/main
else
    echo "NODE_ARGS=\"\"" > $PROCESS_DIR/main
fi

systemctl start $QUIL_SERVICE_NAME@main.service

IS_LINKED="$(yq e '.settings.slave' $QTOOLS_CONFIG_FILE)"
if [ "$IS_LINKED" == "true" ]; then
    MAIN_PID="$(systemctl status $QUIL_SERVICE_NAME | grep 'Main PID' | awk '{print $3}')"
    # if is linked, then start the secondary processes
    CORE_COUNT=$((get_processor_count))
    log Node parent ID: $MAIN_PID;

    for ((i = 1 ; i <= $CORE_COUNT ; i++)); do
        log "Starting service for core $i (parent-process=$NODE_PID)"
        echo "NODE_ARGS=\"--core=$(expr $i) --parent-process=$NODE_PID\"" > $PROCESS_DIR/$i
        systemctl start $QUIL_SERVICE_NAME@$i.service
    done
fi
