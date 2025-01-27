#!/bin/bash

# Check if correct number of arguments provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <source_config.yml> <target_config.yml>"
    exit 1
fi

SOURCE_CONFIG="$1"
TARGET_CONFIG="$2"

# Check if source file exists
if [ ! -f "$SOURCE_CONFIG" ]; then
    echo "Error: Source config file '$SOURCE_CONFIG' not found"
    exit 1
fi

# Check if target file exists
if [ ! -f "$TARGET_CONFIG" ]; then
    echo "Error: Target config file '$TARGET_CONFIG' not found"
    exit 1
fi

# Copy workers from source to target
yq eval '.engine.dataWorkerMultiaddrs = []' "$TARGET_CONFIG" > "${TARGET_CONFIG}.tmp"

if [ $? -ne 0 ]; then
    rm -f "${TARGET_CONFIG}.tmp"
    echo "Error: Failed to clear workers in target file"
    exit 1
fi

yq eval-all '
    select(fileIndex == 0).engine.dataWorkerMultiaddrs = select(fileIndex == 1).engine.dataWorkerMultiaddrs
' "${TARGET_CONFIG}.tmp" "$SOURCE_CONFIG" > "${TARGET_CONFIG}.tmp2"

# Check if the operation was successful
if [ $? -eq 0 ]; then
    mv "${TARGET_CONFIG}.tmp2" "$TARGET_CONFIG"
    rm -f "${TARGET_CONFIG}.tmp"
    echo "Successfully copied workers from $SOURCE_CONFIG to $TARGET_CONFIG"
else
    rm -f "${TARGET_CONFIG}.tmp" "${TARGET_CONFIG}.tmp2"
    echo "Error: Failed to copy workers"
    exit 1
fi
