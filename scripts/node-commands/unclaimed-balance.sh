#!/bin/bash
# HELP: Prints out this node\'s unclaimed balance, in QUILs.
IS_APP_FINISHED_STARTING="$(is_app_finished_starting)"

if [ $IS_APP_FINISHED_STARTING == "true" ]; then
    INPUT="$($LINKED_BINARY_NAME --balance)"

    UNCLAIMED_BALANCE=$(echo "$INPUT" | grep "Unclaimed balance" | awk -F ": " '{print $2}' | awk '{print $1}')
    echo "$UNCLAIMED_BALANCE"
else
    echo "Could not fetch unclaimed.  App hasn't finished starting."
fi




