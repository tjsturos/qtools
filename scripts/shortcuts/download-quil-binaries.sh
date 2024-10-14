#!/bin/bash

# Base URL for the Quilibrium releases
NODE_RELEASE_LIST_URL="https://releases.quilibrium.com/release"

# Fetch the list of files from the release page
NODE_RELEASE_FILES=$(curl -s $NODE_RELEASE_LIST_URL | grep -oE "node-[0-9]+\.[0-9]+(\.[0-9]+)*(\.[0-9]+)?-${OS_ARCH}(\.dgst)?(\.sig\.[0-9]+)?")

# Change to the download directory
mkdir -p $QUIL_NODE_PATH
cd $QUIL_NODE_PATH

download_file() {
    local FILE_NAME=$1
    log "Downloading $FILE_NAME..."
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


QCLIENT_RELEASE_LIST_URL="https://releases.quilibrium.com/qclient-release"
QCLIENT_RELEASE_FILES=$(curl -s $QCLIENT_RELEASE_LIST_URL | grep -oE "qclient-[0-9]+\.[0-9]+(\.[0-9]+)*(\.[0-9]+)?-${OS_ARCH}(\.dgst)?(\.sig\.[0-9]+)?")

mkdir -p $QUIL_CLIENT_PATH
cd $QUIL_CLIENT_PATH

for file in $QCLIENT_RELEASE_FILES; do
    log "Downloading $file..."
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
