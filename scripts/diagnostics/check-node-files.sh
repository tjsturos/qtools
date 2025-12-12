#!/bin/bash

echo "Checking node files..."

# Function to check if node files exist
check_node_files() {
    ls "$QUIL_NODE_PATH"/node-* &> /dev/null
}

# Check for missing node files
if ! check_node_files; then
    echo "ERROR: Missing node files detected." >&2
    echo "Running qtools update-node --force"
    if qtools update-node --force; then
        echo "Node update command completed. Verifying files..."
        if check_node_files; then
            echo "Node files successfully created."
        else
            echo "ERROR: Node files still missing after update attempt." >&2
            exit 1
        fi
    else
        echo "ERROR: Failed to update node files." >&2
        exit 1
    fi
else
    echo "Node files are present."
fi

echo "Node files check completed."