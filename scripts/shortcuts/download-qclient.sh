#!/bin/bash

QCLIENT_VERSION=""

SIGNER_COUNT=17
BINARY_ONLY=false
LINKED_QCLIENT_BINARY=""
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --link|-l)
        LINKED_QCLIENT_BINARY="true"
        shift
        ;;
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

link_qclient() {
    local BINARY_NAME=$1
    echo "Linking $LINKED_QCLIENT_BINARY to $QUIL_CLIENT_PATH/$BINARY_NAME"
    sudo ln -sf $QUIL_CLIENT_PATH/$BINARY_NAME $LINKED_QCLIENT_BINARY
}

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

# Ensure quilibrium user has access if using quilibrium user
SERVICE_USER=$(yq '.service.default_user // "quilibrium"' $QTOOLS_CONFIG_FILE 2>/dev/null || echo "quilibrium")
if [ "$SERVICE_USER" == "quilibrium" ] && id "quilibrium" &>/dev/null; then
    sudo chown -R quilibrium:quilibrium "$QUIL_CLIENT_PATH" 2>/dev/null || true
fi

for file in $QCLIENT_RELEASE_FILES; do
    download_file $file

    if [[ $file =~ ^qclient-[0-9]+\.[0-9]+(\.[0-9]+)*(-[a-zA-Z0-9-]+)?-${OS_ARCH}$ ]]; then
        log "Making $file executable..."
        chmod +x "$file"
        # Ensure quilibrium user owns the file if using quilibrium user
        if [ "$SERVICE_USER" == "quilibrium" ] && id "quilibrium" &>/dev/null; then
            sudo chown quilibrium:quilibrium "$file" 2>/dev/null || true
        fi
        if [ $? -eq 0 ]; then
            log "Successfully made $file executable"
        else
            log "Failed to make $file executable"
        fi

        if [ -n "$LINKED_QCLIENT_BINARY" ];then
            link_qclient $file
        fi
    fi

    log "------------------------"
done

log "Download process completed."
