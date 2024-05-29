#!/bin/bash

check_execstart() {
    SERVICE_FILE="$1"
    START_SCRIPT="$2"
    grep -q "^$START_SCRIPT" "$SERVICE_FILE"
}

# Extract version information
VERSION=$(cat $QUIL_NODE_PATH/config/version.go | grep -A 1 "func GetVersion() \[\]byte {" | grep -Eo '0x[0-9a-fA-F]+' | xargs printf "%d.%d.%d")

log "Found version: $VERSION"

# Determine the binary path based on OS and architecture
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if [[ "$arch" == arm* ]]; then
        QUIL_BIN="node-$VERSION-linux-arm64"
    else
        QUIL_BIN="node-$VERSION-linux-amd64"
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    QUIL_BIN="node-$VERSION-darwin-arm64"
else
    log "Unsupported OS for releases, please build from source."
    exit 1
fi

# Define the new ExecStart line
NEW_EXECSTART="ExecStart=$QUIL_NODE_PATH/$QUIL_BIN"
 
if [ ! -f "$SYSTEMD_SERVICE_PATH/$QUIL_SERVICE_NAME" ]; then
    cp $QTOOLS_PATH/$QUIL_SERVICE_NAME $SYSTEMD_SERVICE_PATH
fi

# Update the service file if needed
if ! check_execstart "$QUIL_SERVICE_FILE" "$NEW_EXECSTART"; then
    # Use sed to replace the ExecStart line in the service file
    sudo sed -i -e "/^ExecStart=/c\\$NEW_EXECSTART" "$QUIL_SERVICE_FILE"

    # Reload the systemd manager configuration
    sudo systemctl daemon-reload

    log "Systemctl binary version updated to $QUIL_BIN"
fi

DEBUG_SERVICE_FILE=$QUIL_SERVICE_FILE-debug.service

if [ ! -f "$SYSTEMD_SERVICE_PATH/$QUIL_DEBUG_SERVICE_NAME" ]; then
    cp $QTOOLS_PATH/$QUIL_DEBUG_SERVICE_NAME $SYSTEMD_SERVICE_PATH
fi

NEW_DEBUG_EXECSTART="ExecStart=$QUIL_NODE_PATH/$QUIL_BIN --debug"
if ! check_execstart "$DEBUG_SERVICE_FILE" "$NEW_DEBUG_EXECSTART"; then
    # Use sed to replace the ExecStart line in the service file
    sudo sed -i -e "/^ExecStart=/c\\$NEW_DEBUG_EXECSTART" "$DEBUG_SERVICE_FILE"

    # Reload the systemd manager configuration
    sudo systemctl daemon-reload

    log "DEBUG Systemctl binary version updated to $QUIL_BIN"
fi