#!/bin/bash

# Check if the required parameter is provided
if [ $# -eq 0 ]; then
    echo "Error: Missing required parameter. Usage: $0 <int>"
    exit 1
fi

# Ensure the parameter is an integer
if ! [[ $1 =~ ^[0-9]+$ ]]; then
    echo "Error: Parameter must be an integer."
    exit 1
fi

# Get the index from the parameter
INDEX=$1

# Use yq to get the specified line from the dataWorkerMultiaddrs array
RESULT=$(yq eval ".engine.dataWorkerMultiaddrs[$INDEX]" "$QUIL_CONFIG_FILE")

# Check if the result is null (index out of range)
if [ "$RESULT" = "null" ]; then
    echo "Error: Index out of range."
    exit 1
fi

# Output the result
echo "$RESULT"
