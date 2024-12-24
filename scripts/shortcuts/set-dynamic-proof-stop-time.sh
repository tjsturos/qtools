#!/bin/bash

# Check if argument is provided
if [ $# -ne 1 ]; then
    echo "Usage: qtools set-dynamic-proof-stop-time <seconds>"
    exit 1
fi

# Validate input is a positive integer
if ! [[ $1 =~ ^[0-9]+$ ]]; then
    echo "Error: Please provide a positive integer for seconds"
    exit 1
fi

# Set the dynamic proof stop time
yq eval -i ".engine.dynamicProofStopTime = \"$1\"" $QUIL_CONFIG_FILE

echo "Set dynamic proof stop time to ${1}s"
