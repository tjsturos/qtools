#!/bin/bash
cd $QUIL_PATH

# Function to check if the ExecStart line matches the desired one
check_execstart() {
    grep -q "^ExecStart=$QUIL_NODE_PATH/$QUIL_BIN" "$QUIL_SERVICE_FILE"
}

# Fetch the latest changes from the remote repository
git fetch origin


# Make sure we are using the release branch
git checkout release

# Check if there are any new commits on the remote release branch
LOCAL=$(git rev-parse release)
REMOTE=$(git rev-parse origin/release)
if [ $LOCAL != $REMOTE ]; then  
    qtools stop
    log "The 'release' branch has been updated. Pulling changes and restarting service..."
    
    # Pull the latest changes from the remote repository
    git pull
    
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

    # Update the service file if needed
    if ! check_execstart; then
        # Use sed to replace the ExecStart line in the service file
        sudo sed -i -e "/^ExecStart=/c\\$NEW_EXECSTART" "$QUIL_SERVICE_FILE"

        # Reload the systemd manager configuration
        sudo systemctl daemon-reload

        log "Systemctl binary version updated to $QUIL_BIN"
    fi

    qtools start
else
    log "Release branch is up-to-date. No restart required."
fi