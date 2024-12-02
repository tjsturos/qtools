#!/bin/bash

# Parse command line arguments
NODE_VERSION=""

SIGNER_COUNT=17
BINARY_ONLY=""
LINK=""
DEV_BUILD=""

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --link|-l)
        LINK="true"
        shift
        ;;
        --version)
        NODE_VERSION="$2"
        shift # past argument
        shift # past value
        ;;
        --signer-count)
        SIGNER_COUNT="$2"
        shift # past argument
        shift # past value
        ;;
        --no-signatures)
        BINARY_ONLY="true"
        shift # past argument
        ;;
        --dev-build)
        DEV_BUILD="true"
        BINARY_ONLY="true"
        shift # past argument
        ;;
        *)    # unknown option
        shift # past argument
        ;;
    esac
done


# If NODE_VERSION is set, get release files for that specific version
if [ -n "$NODE_VERSION" ]; then
    NODE_RELEASE_FILES="node-${NODE_VERSION}-${OS_ARCH}"
    if [ "$BINARY_ONLY" != "true" ]; then
        NODE_RELEASE_FILES+=" node-${NODE_VERSION}-${OS_ARCH}.dgst"
        for i in $(seq 1 $SIGNER_COUNT); do
            NODE_RELEASE_FILES+=" node-${NODE_VERSION}-${OS_ARCH}.dgst.sig.$i"
        done
    fi
else
    # Fetch the list of latest files from the release page
    NODE_RELEASE_LIST_URL="https://releases.quilibrium.com/release"
    NODE_RELEASE_FILES=$(curl -s $NODE_RELEASE_LIST_URL | grep -oE "node-[0-9]+\.[0-9]+(\.[0-9]+)*(\.[0-9]+)?-${OS_ARCH}(\.dgst)?(\.sig\.[0-9]+)?")
fi

# Change to the download directory
mkdir -p $QUIL_NODE_PATH
cd $QUIL_NODE_PATH

link_node() {
    local BINARY_NAME=$1
    echo "Linking $LINK to $QUIL_NODE_PATH/$BINARY_NAME"
    sudo ln -sf "$QUIL_NODE_PATH/$BINARY_NAME" "$LINKED_NODE_BINARY"
}

download_file() {
    local FILE_NAME=$1
    # Check if the file already exists
    if [ -f "$FILE_NAME" ]; then
        echo "$FILE_NAME already exists. Skipping download."
        return
    fi
    
    echo "Downloading $FILE_NAME..."
    # Check if the remote file exists
    if ! wget --spider "https://releases.quilibrium.com/$FILE_NAME" 2>/dev/null; then
        echo "Remote file $FILE_NAME does not exist. Skipping download."
        return
    fi
    wget "https://releases.quilibrium.com/$FILE_NAME"

    # Check if the download was successful
    if [ $? -eq 0 ]; then
        echo "Successfully downloaded $FILE_NAME"
        # Check if the file is the base binary (without .dgst or .sig suffix)
       
    else
        echo "Failed to download $file"
    fi
}

download_dev_build() {
    # Get backup settings from config
    SSH_KEY_PATH=$(yq eval '.scheduled_tasks.backup.ssh_key_path' $QTOOLS_CONFIG_FILE)
    REMOTE_USER=$(yq eval '.scheduled_tasks.backup.remote_user' $QTOOLS_CONFIG_FILE)
    REMOTE_URL=$(yq eval '.scheduled_tasks.backup.backup_url' $QTOOLS_CONFIG_FILE)
    

    # Test SSH connection before proceeding
    if ! ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 "$REMOTE_USER@$REMOTE_URL" exit 2>/dev/null; then
        echo "Error: Cannot connect to remote host. Please check your SSH configuration and network connection."
        return 1
    fi

    echo "Downloading development build from backup location..."

    # Check if development build exists on remote server
    if ! ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$REMOTE_USER@$REMOTE_URL" "test -f $HOME/dev-builds/$NODE_VERSION"; then
        echo "Error: Development build $NODE_VERSION not found on remote server"
        return 1
    fi

    rsync -avzP \
        -e "ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
        "$REMOTE_USER@$REMOTE_URL:$HOME/dev-builds/$NODE_VERSION" \
        "$QUIL_NODE_PATH/"

    if [ $? -eq 0 ]; then
        echo "Successfully downloaded development build"
        chmod +x "$QUIL_NODE_PATH/$NODE_VERSION"
        if [ -n "$LINK" ]; then
            link_node "$NODE_VERSION"
        fi
    else
        echo "Failed to download development build"
        return 1
    fi
}

# Download each file
for file in $NODE_RELEASE_FILES; do
    download_file $file

    if [[ $file =~ ^node-[0-9]+\.[0-9]+(\.[0-9]+)*(-[a-zA-Z0-9-]+)?-${OS_ARCH}$ ]]; then
        echo "Making $file executable..."
        chmod +x "$file"
        if [ $? -eq 0 ]; then
            echo "Successfully made $file executable"
        else
            echo "Failed to make $file executable"
        fi

        if [ -n "$LINK" ];then
            link_node $file
        fi
    fi
    
    echo "------------------------"
done

echo "Download process completed."
