#!/bin/bash
# HELP: Prints details about this node.

cd $QUIL_NODE_PATH

CMD="$LINKED_NODE_BINARY --node-info"
# Check if --skip-signature-check flag is provided
if [[ "$*" == *"--skip-signature-check"* ]]; then
    CMD="$CMD --signature-check=false"
fi

$CMD
