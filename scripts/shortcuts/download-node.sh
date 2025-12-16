#!/bin/bash

# Parse command line arguments
NODE_VERSION=""

SIGNER_COUNT=17
BINARY_ONLY=""
LINK=""
DEV_BUILD=""
USE_AVX512="$(yq '.settings.use_avx512' $QTOOLS_CONFIG_FILE)"
TESTNET=""
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --link|-l)
        LINK="true"
        shift
        ;;
        --version|-v)
        NODE_VERSION="$2"
        shift # past argument
        shift # past value
        ;;
        --signer-count)
        SIGNER_COUNT="$2"
        shift # past argument
        shift # past value
        ;;
        --testnet|-t)
        TESTNET="true"
        BINARY_ONLY="true"
        shift # past argument
        ;;
        --no-signatures|-ns)
        BINARY_ONLY="true"
        shift # past argument
        ;;
        --dev-build|--dev|-d)
        DEV_BUILD="true"
        BINARY_ONLY="true"
        echo "Fetching Dev Build"
        shift # past argument
        ;;
        --use-avx512|-avx512)
        USE_AVX512="true"
        shift # past argument
        ;;
        *)    # unknown option
        shift # past argument
        ;;
    esac
done

# Disable AVX512 for non-linux-amd64 architectures
if [ "$OS_ARCH" != "linux-amd64" ] || [ "$USE_AVX512" != "true" ]; then
    USE_AVX512=""
fi



# If NODE_VERSION is set, get release files for that specific version
if [ -n "$NODE_VERSION" ]; then
    NODE_RELEASE_FILES="node-${NODE_VERSION}-${OS_ARCH}${USE_AVX512:+-avx512}"
    if [ "$BINARY_ONLY" != "true" ] && [ "$DEV_BUILD" != "true" ]; then
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
sudo mkdir -p $QUIL_NODE_PATH

# Ensure quilibrium user has access if using quilibrium user
SERVICE_USER=$(yq '.service.default_user // "quilibrium"' $QTOOLS_CONFIG_FILE 2>/dev/null || echo "quilibrium")
if [ "$SERVICE_USER" == "quilibrium" ]; then
    # Ensure quilibrium user exists
    if id "quilibrium" &>/dev/null; then
        # Set ownership to quilibrium:qtools for new directories/files
        sudo chown -R quilibrium:$QTOOLS_GROUP "$QUIL_NODE_PATH" 2>/dev/null || true
        # Ensure qtools group can read, write, and execute
        sudo chmod -R g+rwx "$QUIL_NODE_PATH" 2>/dev/null || true
        # Ensure the directory is accessible (readable and executable) by others so we can cd into it
        sudo chmod u+rx "$QUIL_NODE_PATH" 2>/dev/null || true
    fi
fi

# Change to the download directory after ensuring permissions
if [ -d "$QUIL_NODE_PATH" ] && [ -r "$QUIL_NODE_PATH" ] && [ -x "$QUIL_NODE_PATH" ]; then
    cd "$QUIL_NODE_PATH" || {
        log "Error: Cannot change to directory $QUIL_NODE_PATH. Permission denied."
        exit 1
    }
else
    log "Error: Directory $QUIL_NODE_PATH does not exist or is not accessible."
    exit 1
fi

link_node() {
    local BINARY_NAME=$1
    local BINARY_PATH="$QUIL_NODE_PATH/$BINARY_NAME"

    # Ensure binary exists and has correct permissions
    if [ ! -f "$BINARY_PATH" ]; then
        echo "Error: Binary not found at $BINARY_PATH"
        return 1
    fi

    # Ensure quilibrium user owns the binary if using quilibrium user
    if [ "$SERVICE_USER" == "quilibrium" ] && id "quilibrium" &>/dev/null; then
        sudo chown quilibrium:$QTOOLS_GROUP "$BINARY_PATH" 2>/dev/null || true
        sudo chmod g+rwx "$BINARY_PATH" 2>/dev/null || true
        sudo chmod +x "$BINARY_PATH" 2>/dev/null || true
    fi

    echo "Linking $LINKED_NODE_BINARY to $BINARY_PATH"
    sudo ln -sf "$BINARY_PATH" "$LINKED_NODE_BINARY"

    # Verify the symlink was created correctly
    LINK_TARGET=$(readlink -f "$LINKED_NODE_BINARY" 2>/dev/null || echo "")
    if [ "$LINK_TARGET" != "$BINARY_PATH" ]; then
        echo "Warning: Symlink target mismatch. Expected: $BINARY_PATH, Got: $LINK_TARGET"
    fi

    # Persist the current node version to config after linking
    local VERSION_FROM_LINK=$(basename "$BINARY_NAME" | grep -oP "node-\K([0-9]+\.?)+")
    if [[ -n "$VERSION_FROM_LINK" ]]; then
        set_current_node_version "$VERSION_FROM_LINK"
    fi

    if [ "$DEV_BUILD" == "true" ]; then
        qtools update-service --skip-sig-check
    fi
}

download_file() {
    local FILE_NAME=$1
    local DEST_FILE="$QUIL_NODE_PATH/$FILE_NAME"

    # Check if the file already exists
    if [ -f "$DEST_FILE" ]; then
        echo "$FILE_NAME already exists. Skipping download."
        return
    fi

    echo "Downloading $FILE_NAME..."

    if [ "$DEV_BUILD" != "true" ]; then
        # Check if the remote file exists
        if ! wget --spider "https://releases.quilibrium.com/$FILE_NAME" 2>/dev/null; then
            echo "Remote file $FILE_NAME does not exist. Skipping download."
            return
        fi
        # Download to temp location first, then move with proper ownership
        TEMP_FILE=$(mktemp)
        if wget "https://releases.quilibrium.com/$FILE_NAME" -O "$TEMP_FILE"; then
            # Move to destination with proper ownership
            if [ "$SERVICE_USER" == "quilibrium" ] && id "quilibrium" &>/dev/null; then
                sudo mv "$TEMP_FILE" "$DEST_FILE"
                sudo chown quilibrium:$QTOOLS_GROUP "$DEST_FILE" 2>/dev/null || true
                sudo chmod g+rwx "$DEST_FILE" 2>/dev/null || true
            else
                mv "$TEMP_FILE" "$DEST_FILE"
            fi
            echo "Successfully downloaded $FILE_NAME"
        else
            rm -f "$TEMP_FILE"
            echo "Failed to download $FILE_NAME"
        fi
    else
        # Dev build - download directly
        TEMP_FILE=$(mktemp)
        if wget --no-check-certificate "https://dev.qcommander.sh/$FILE_NAME" -O "$TEMP_FILE"; then
            if [ "$SERVICE_USER" == "quilibrium" ] && id "quilibrium" &>/dev/null; then
                sudo mv "$TEMP_FILE" "$DEST_FILE"
                sudo chown quilibrium:$QTOOLS_GROUP "$DEST_FILE" 2>/dev/null || true
                sudo chmod g+rwx "$DEST_FILE" 2>/dev/null || true
            else
                mv "$TEMP_FILE" "$DEST_FILE"
            fi
            echo "Successfully downloaded $FILE_NAME"
        else
            rm -f "$TEMP_FILE"
            echo "Failed to download $FILE_NAME"
        fi
    fi
}

# Download each file
for file in $NODE_RELEASE_FILES; do
    download_file $file

    if [[ $file =~ ^node-[0-9]+\.[0-9]+(\.[0-9]+)*(-[a-zA-Z0-9-]+)?-${OS_ARCH}$ ]]; then
        BINARY_FILE="$QUIL_NODE_PATH/$file"
        echo "Making $file executable..."
        if [ "$SERVICE_USER" == "quilibrium" ] && id "quilibrium" &>/dev/null; then
            sudo chmod +x "$BINARY_FILE"
            sudo chown quilibrium:$QTOOLS_GROUP "$BINARY_FILE" 2>/dev/null || true
            sudo chmod g+rwx "$BINARY_FILE" 2>/dev/null || true
        else
            chmod +x "$BINARY_FILE"
        fi
        if [ $? -eq 0 ]; then
            echo "Successfully made $file executable"
        else
            echo "Failed to make $file executable"
        fi

        if [ -n "$LINK" ];then
            link_node $file
        fi

        if [ "$TESTNET" == "true" ]; then
            qtools update-service --skip-sig-check --testnet
        elif [ "$DEV_BUILD" == "true" ] || [ "$BINARY_ONLY" == "true" ]; then
            qtools update-service --skip-sig-check
        fi
    fi

    echo "------------------------"
done

echo "Download process completed."
