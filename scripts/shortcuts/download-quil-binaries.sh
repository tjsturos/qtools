#!/bin/bash

# Base URL for the Quilibrium releases
RELEASE_LIST_URL="https://releases.quilibrium.com/release"

# Fetch the list of files from the release page
RELEASE_FILES=$(curl -s $RELEASE_LIST_URL | grep -oE "node-[0-9]+\.[0-9]+\.[0-9]+-${OS_ARCH}(\.dgst)?(\.sig\.[0-9]+)?")

# Change to the download directory
mkdir -p ~/ceremonyclient/node
cd ~/ceremonyclient/node

# Download each file
for file in $RELEASE_FILES; do
    log "Downloading $file..."
    wget "https://releases.quilibrium.com/$file"

    # Check if the download was successful
    if [ $? -eq 0 ]; then
        log "Successfully downloaded $file"
        # Check if the file is the base binary (without .dgst or .sig suffix)
        if [[ $file =~ ^node-[0-9]+\.[0-9]+\.[0-9]+-${OS_ARCH}$ ]]; then
            log "Making $file executable..."
            chmod +x "$file"
            if [ $? -eq 0 ]; then
                log "Successfully made $file executable"
            else
                log "Failed to make $file executable"
            fi
        fi
    else
        log "Failed to download $file"
    fi
    
    log "------------------------"
done

log "Download process completed."
