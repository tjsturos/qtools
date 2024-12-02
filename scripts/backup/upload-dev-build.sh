#!/bin/bash

# Parse command line arguments
SOURCE_FILE=""
VERSION_NAME=""

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --file)
        SOURCE_FILE="$2"
        shift # past argument
        shift # past value
        ;;
        --version)
        VERSION_NAME="$2"
        shift # past argument
        shift # past value
        ;;
        *)    # unknown option
        shift # past argument
        ;;
    esac
done

# Validate required parameters
if [ -z "$SOURCE_FILE" ] || [ -z "$VERSION_NAME" ]; then
    echo "Error: Both --file and --version parameters are required"
    echo "Usage: qtools upload-dev-build --file <path-to-file> --version <version-name>"
    exit 1
fi

# Check if source file exists
if [ ! -f "$SOURCE_FILE" ]; then
    echo "Error: Source file $SOURCE_FILE does not exist"
    exit 1
fi

# Get backup settings from config
SSH_KEY_PATH=$(yq eval '.scheduled_tasks.backup.ssh_key_path' $QTOOLS_CONFIG_FILE)
REMOTE_USER=$(yq eval '.scheduled_tasks.backup.remote_user' $QTOOLS_CONFIG_FILE)
REMOTE_URL=$(yq eval '.scheduled_tasks.backup.backup_url' $QTOOLS_CONFIG_FILE)

# Test SSH connection before proceeding
if ! ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 "$REMOTE_USER@$REMOTE_URL" exit 2>/dev/null; then
    echo "Error: Cannot connect to remote host. Please check your SSH configuration and network connection."
    exit 1
fi

# Create dev-builds directory if it doesn't exist
ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$REMOTE_USER@$REMOTE_URL" "mkdir -p ~/dev-builds"

echo "Uploading $SOURCE_FILE as version $VERSION_NAME..."

# Upload the file
rsync -avzP \
    -e "ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
    "$SOURCE_FILE" \
    "$REMOTE_USER@$REMOTE_URL:~/dev-builds/$VERSION_NAME"

if [ $? -eq 0 ]; then
    echo "Successfully uploaded development build"
else
    echo "Failed to upload development build"
    exit 1
fi
