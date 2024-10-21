#!/bin/bash

QCLIENT_VERSION=""

SIGNER_COUNT=17
BINARY_ONLY=false
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --signer-count)
        SIGNER_COUNT="$2"
        shift # past argument
        shift # past value
        ;;
        --version)
        QCLIENT_VERSION="$2"
        shift # past argument
        shift # past value
        ;;
        --no-signatures)
        BINARY_ONLY=true
        shift # past argument
        ;;
        *)    # unknown option
        shift # past argument
        ;;
    esac
done

download_file() {
    local FILE_NAME=$1
    # Check if the file already exists
    if [ -f "$FILE_NAME" ]; then
        log "$FILE_NAME already exists. Skipping download."
        return
    fi
    
    log "Downloading $FILE_NAME..."
    # Check if the remote file exists
    if ! wget --spider "https://releases.quilibrium.com/$FILE_NAME" 2>/dev/null; then
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

if [ -n "$QCLIENT_VERSION" ]; then
    QCLIENT_RELEASE_FILES="qclient-${QCLIENT_VERSION}-${OS_ARCH}"
    if [ "$BINARY_ONLY" == "false" ]; then
        QCLIENT_RELEASE_FILES+=" qclient-${QCLIENT_VERSION}-${OS_ARCH}.dgst"
        for i in $(seq 1 $SIGNER_COUNT); do
            QCLIENT_RELEASE_FILES+=" qclient-${QCLIENT_VERSION}-${OS_ARCH}.dgst.sig.$i"
        done
    fi
else
    QCLIENT_RELEASE_LIST_URL="https://releases.quilibrium.com/qclient-release"
    QCLIENT_RELEASE_FILES=$(curl -s $QCLIENT_RELEASE_LIST_URL | grep -oE "qclient-[0-9]+\.[0-9]+(\.[0-9]+)*(\.[0-9]+)?-${OS_ARCH}(\.dgst)?(\.sig\.[0-9]+)?")
fi

mkdir -p $QUIL_CLIENT_PATH
cd $QUIL_CLIENT_PATH

for file in $QCLIENT_RELEASE_FILES; do
    download_file $file

    if [[ $file =~ ^qclient-[0-9]+\.[0-9]+(\.[0-9]+)*(-[a-zA-Z0-9-]+)?-${OS_ARCH}$ ]]; then
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
