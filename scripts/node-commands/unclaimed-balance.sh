#!/bin/bash
# HELP: Prints out this node\'s unclaimed balance, in QUILs.
IS_APP_FINISHED_STARTING="$(is_app_finished_starting)"

if [[ $IS_APP_FINISHED_STARTING == "true" ]]; then
    if qclient_fn token balance &>/dev/null; then
        OUTPUT="$(qclient_fn token balance)"
        UNCLAIMED_BALANCE=$(echo "$OUTPUT" | awk '{print $1}')
        echo "$UNCLAIMED_BALANCE"
    else
        INPUT="$($QUIL_NODE_PATH/$(get_versioned_node) -balance)"
        UNCLAIMED_BALANCE=$(echo "$INPUT" | grep "Unclaimed balance" | awk -F ": " '{print $2}' | awk '{print $1}')
        echo "$UNCLAIMED_BALANCE"
    fi
else
    echo "Could not fetch unclaimed balance. App hasn't finished starting."
fi




