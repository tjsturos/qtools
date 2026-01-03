#!/bin/bash
# HELP: Prints details about this node.

# Check if --skip-signature-check flag is provided
if [[ "$*" == *"--skip-signature-check"* ]]; then
    run_node_command --node-info "$@" --signature-check=false
else
    run_node_command --node-info "$@"
fi
