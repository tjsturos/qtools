#!/bin/bash
# HELP: Prints out this node\'s unclaimed balance, in QUILs
INPUT="$($QUIL_NODE_PATH/$QUIL_BIN -balance)"

UNCLAIMED_BALANCE=$(echo "$INPUT" | grep "Unclaimed balance" | awk -F ": " '{print $2}' | awk '{print $1}')

echo "$UNCLAIMED_BALANCE"
