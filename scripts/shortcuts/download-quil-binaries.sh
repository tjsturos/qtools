#!/bin/bash

# Parse command line arguments
NODE_VERSION=""
QCLIENT_VERSION=""
SIGNER_COUNT=17
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --node-version)
        NODE_VERSION="$2"
        shift # past argument
        shift # past value
        ;;
        --signer-count)
        SIGNER_COUNT="$2"
        shift # past argument
        shift # past value
        ;;
        --qclient-version)
        QCLIENT_VERSION="$2"
        shift # past argument
        shift # past value
        ;;
        *)    # unknown option
        shift # past argument
        ;;
    esac
done

# If NODE_VERSION is set, get release files for that specific version
if [ -n "$NODE_VERSION" ]; then
    NODE_RELEASE_FILES="node-${NODE_VERSION}-${OS_ARCH} node-${NODE_VERSION}-${OS_ARCH}.dgst"
    for i in $(seq 1 $SIGNER_COUNT); do
        NODE_RELEASE_FILES+=" node-${NODE_VERSION}-${OS_ARCH}.sig.$i"
    done
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
        log "$FILE_NAME already exists. Skipping download."
        return
    fi
    
    log "Downloading $FILE_NAME..."
    # Check if the remote file exists
    if wget --spider "https://releases.quilibrium.com/$FILE_NAME" 2>/dev/null; then
        log "Remote file $FILE_NAME exists. Proceeding with download."
    else
        log "Remote file $FILE_NAME does not exist. Skipping download."
        return
    fi
    wget "https://releases.quilibrium.com/$FILE_NAME"

    # Check if the download was successful
    if [ $? -eq 0 ]; then
        log "Successfully downloaded $FILE_NAME"
        # Check if the file is the base binary (without .dgst or .sig suffix)
       
    else
        log "Failed to download $file"
    fi

}

# Download each file
for file in $NODE_RELEASE_FILES; do
    download_file $file

    if [[ $file =~ ^node-[0-9]+\.[0-9]+(\.[0-9]+)*(\.[0-9]+)?-${OS_ARCH}$ ]]; then
        log "Making $file executable..."
        chmod +x "$file"
        if [ $? -eq 0 ]; then
            log "Successfully made $file executable"
        else
            log "Failed to make $file executable"
        fi
    fi
    
    log "------------------------"
done

if [ -n "$QCLIENT_VERSION" ]; then
    QCLIENT_RELEASE_FILES="qclient-${QCLIENT_VERSION}-${OS_ARCH} qclient-${QCLIENT_VERSION}-${OS_ARCH}.dgst"
    for i in $(seq 1 $SIGNER_COUNT); do
        if wget --spider "https://releases.quilibrium.com/qclient-${QCLIENT_VERSION}-${OS_ARCH}.sig.$i" 2>/dev/null; then
            QCLIENT_RELEASE_FILES+=" qclient-${QCLIENT_VERSION}-${OS_ARCH}.sig.$i"
        fi
    done
else
    QCLIENT_RELEASE_LIST_URL="https://releases.quilibrium.com/qclient-release"
    QCLIENT_RELEASE_FILES=$(curl -s $QCLIENT_RELEASE_LIST_URL | grep -oE "qclient-[0-9]+\.[0-9]+(\.[0-9]+)*(\.[0-9]+)?-${OS_ARCH}(\.dgst)?(\.sig\.[0-9]+)?")
fi

mkdir -p $QUIL_CLIENT_PATH
cd $QUIL_CLIENT_PATH

for file in $QCLIENT_RELEASE_FILES; do
    download_file $file

    if [[ $file =~ ^qclient-[0-9]+\.[0-9]+(\.[0-9]+)*(\.[0-9]+)?-${OS_ARCH}$ ]]; then
        log "Making $file executable..."
        chmod +x "$file"
        if [ $? -eq 0 ]; then
            log "Successfully made $file executable"
        else
            log "Failed to make $file executable"
        fi
    fi
    
    log "------------------------"
done

log "Download process completed."
