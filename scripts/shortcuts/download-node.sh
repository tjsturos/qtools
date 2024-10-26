#!/bin/bash

# Parse command line arguments
NODE_VERSION=""

SIGNER_COUNT=17
BINARY_ONLY=""
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
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
    fi
    
    echo "------------------------"
done

echo "Download process completed."
