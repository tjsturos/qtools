#!/bin/bash
# HELP: Prints details about this node.

CMD="$(run_node_command --node-info)"
# Check if --skip-signature-check flag is provided
if [[ "$*" == *"--skip-signature-check"* ]]; then
    CMD="$CMD --signature-check=false"
fi

$CMD
