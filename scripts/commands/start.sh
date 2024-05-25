#!/bin/bash

# Extract version information
version=$(cat $QUIL_NODE_PATH/config/version.go | grep -A 1 "func GetVersion() \[\]byte {" | grep -Eo '0x[0-9a-fA-F]+' | xargs printf "%d.%d.%d")

echo "Found version: $version"

# Determine the binary path based on OS and architecture
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if [[ "$arch" == arm* ]]; then
        QUIL_BIN="node-$version-linux-arm64"
    else
        QUIL_BIN="node-$version-linux-amd64"
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    QUIL_BIN="node-$version-darwin-arm64"
else
    echo "unsupported OS for releases, please build from source"
    exit 1
fi

# Define the new ExecStart line
NEW_EXECSTART="ExecStart=$QUIL_NODE_PATH/$QUIL_BIN"

# Function to check if the ExecStart line matches the desired one
check_execstart() {
    grep -q "^ExecStart=$QUIL_BIN" "$QUIL_SERVICE_FILE"
}

# Update the service file if needed
if ! check_execstart; then
    # Use sed to replace the ExecStart line in the service file
    sudo sed -i -e "/^ExecStart=/c\\$NEW_EXECSTART" "$QUIL_SERVICE_FILE"

    # Reload the systemd manager configuration
    sudo systemctl daemon-reload

    # Restart the service to apply the changes
    sudo systemctl restart ceremonyclient.service
    echo "Systemctl version updated and service restarted."
else
    echo "ExecStart is already set to use $QUIL_BIN. No changes made."
    # Start the service (if it isn't already running)
    sudo systemctl start ceremonyclient.service
fi