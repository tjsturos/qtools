#!/bin/bash
# HELP: Prints out this node\'s unclaimed balance, in QUILs.
IS_APP_FINISHED_STARTING="$(is_app_finished_starting)"

if [[ $IS_APP_FINISHED_STARTING == "true" ]]; then
    if [[ -f "$QUIL_QCLIENT_BIN" ]]; then
        OUTPUT="$($QUIL_QCLIENT_BIN token balance)"
        UNCLAIMED_BALANCE=$(echo "$OUTPUT" | awk '{print $1}')
        echo "$UNCLAIMED_BALANCE"
    else
        INPUT="$($QUIL_NODE_PATH/$QUIL_BIN -balance)"
        UNCLAIMED_BALANCE=$(echo "$INPUT" | grep "Unclaimed balance" | awk -F ": " '{print $2}' | awk '{print $1}')
        echo "$UNCLAIMED_BALANCE"
    fi
else
    echo "Could not fetch unclaimed balance. App hasn't finished starting."
fi




