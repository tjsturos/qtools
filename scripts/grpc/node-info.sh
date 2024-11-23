#!/bin/bash
# HELP: Prints details about this node.

cd $QUIL_NODE_PATH

SIGNATURE_CHECK=$(yq '.service.signature_check // ""' $QTOOLS_CONFIG_FILE)

CMD="$LINKED_NODE_BINARY ${SIGNATURE_CHECK:+--signature-check=false} --node-info"
# Check if --skip-signature-check flag is provided
if [[ "$*" == *"--skip-signature-check"* ]]; then
    CMD="$CMD --signature-check=false"
fi

$CMD
