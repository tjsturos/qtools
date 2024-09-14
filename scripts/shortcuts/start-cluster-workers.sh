#!/bin/bash

# Default values
COUNT=1
INDEX_START=1

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --count)
            COUNT="$2"
            shift 2
            ;;
        --index-start)
            INDEX_START="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate COUNT
if ! [[ "$COUNT" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: --count must be a non-zero unsigned integer"
    exit 1
fi

# Validate INDEX_START
if ! [[ "$INDEX_START" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: --index-start must be a non-zero unsigned integer"
    exit 1
fi

# Get the versioned node binary
BINARY="$(get_versioned_node)"

# Start the workers
for ((i=0; i<COUNT; i++)); do
    CORE=$((INDEX_START + i))
    $QUIL_NODE_PATH/$BINARY --core $CORE &
    echo "Started worker for core $CORE"
done

wait
