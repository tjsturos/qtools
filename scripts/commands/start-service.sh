#!/bin/bash

# start the main process
DEBUG_MODE="$(yq e '.settings.debug' $QTOOLS_CONFIG_FILE)"
if [ $DEBUG_MODE == 'true']; then
    get_versioned_binary --debug
else
    get_versioned_binary
fi
NODE_PID=$!

IS_LINKED="$(yq e '.settings.slave' $QTOOLS_CONFIG_FILE)"
if [ $IS_LINKED == 'true' ]; then
    # if is linked, then start the secondary processes
    CORE_COUNT=$(get_processor_count)
    log Node parent ID: $NODE_PID;

    for I in {1..$CORE_COUNT}; do
        get_versioned_binary --core=$(expr $I) --parent-process=$NODE_PID &
    done
fi

fi