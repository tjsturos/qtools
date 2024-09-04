log() {
    MESSAGE="$1"
    SHOULD_OUTPUT="${2:-true}"

    if [ -z "$LOG_OUTPUT_PATH" ]; then
        LOG_OUTPUT_FILE=$(yq '.settings.log_file' $QTOOLS_CONFIG_FILE)
    fi

    if [[ ! -f "$QTOOLS_PATH/$LOG_OUTPUT_FILE" ]]; then
        touch $QTOOLS_PATH/$LOG_OUTPUT_FILE
    fi

    LOG="$(date) - $1"
    if [ "$SHOULD_OUTPUT" != "false" ]; then
            echo "$LOG"
    fi

    echo "$LOG" >> "$QTOOLS_PATH/$LOG_OUTPUT_FILE"
}

get_last_started_at() {
    local log_file="$QUIL_LOG_FILE"
    local ts_line=$(grep -m 1 '"ts":' "$log_file")
    if [ -n "$ts_line" ]; then
        local ts=$(echo "$ts_line" | grep -o '"ts":[0-9.]*' | cut -d':' -f2)
        echo "$ts"
    else
        echo "No timestamp found in log file"
    fi
}

is_app_finished_starting() {
    if grep -q 'peers in store' "$QUIL_LOG_FILE"; then
        echo "true"
    else
        echo "false"
    fi
}

append_to_file() {
    FILE="$1"
    CONTENT="$2"
    LOG_OUTPUT="${3:-true}"

    if ! grep -qFx "$CONTENT" $FILE 2>/dev/null; then
        
        log "Adding $CONTENT to $FILE" $LOG_OUTPUT
        
        echo "$CONTENT" | sudo tee -a $FILE > /dev/null
    else
        log "$CONTENT already found in $FILE. Skipping." $LOG_OUTPUT
    fi
}

remove_directory() {
    DIRECTORY="$1"
    LOG_OUTPUT="${2:-true}"
    if [ -d "$DIRECTORY" ]; then
        log "Directory $DIRECTORY found.  Removing." $LOG_OUTPUT
        
        sudo rm -rf $DIRECTORY
        if [ ! -d $DIRECTORY ]; then
            log "Directory $DIRECTORY deletion was successful." $LOG_OUTPUT
        else
            log "Directory $DIRECTORY deletion was not successful." $LOG_OUTPUT
        fi
    fi
}

remove_file() {
    FILE="$1"
    LOG_OUTPUT="${2:-true}"
    if [ -f "$FILE" ]; then
        log "File $FILE found.  Removing." $LOG_OUTPUT
        
        sudo rm $FILE
        if [ ! -f $FILE ]; then
            log "File $FILE deletion was successful." $LOG_OUTPUT
        else
            log "File $FILE deletion was not successful." $LOG_OUTPUT
        fi
    else
        log "$FILE file not found." $LOG_OUTPUT
    fi
}

file_exists() {
    FILE="$1"
    if [ ! -f $FILE ]; then
        log "File $FILE exists."
    else
        log "File $FILE does not exist."
    fi
}


command_exists() {
  command -v "$1" >/dev/null 2>&1
}

install_package() {
    package="$1"
    command="$2"
    if ! command_exists $command; then
        log "$package is not installed. Installing..."

        # For macOS, we'll use Homebrew
        if ! command_exists brew; then
            log "Homebrew is not installed. Please install Homebrew first: https://brew.sh/"
            exit 1
        fi

        brew install $package

        # Verify if the installation was successful
        if command_exists $command; then
            log "$package was successfully installed and $command is now available for use." 
        else
            log "Failed to install $package. Please try installing it manually."
            exit 1
        fi
    fi
}

# Function to remove lines from a file if they match the starting pattern
remove_lines_matching_pattern() {
    local file="$1"
    local pattern="$2"

    if [[ -z "$file" || -z "$pattern" ]]; then
        echo "Usage: remove_lines_matching_pattern <file> <pattern>"
        return 1
    fi

    # Use sed to remove lines matching the specified pattern (macOS version)
    sudo sed -i '' "/$pattern/d" "$file"
}

set_release_version() {
    new_version="$1" 
    yq -i e '.release_version = strenv(new_version)' $QTOOLS_CONFIG_FILE
}

fetch_release_version() {
    local RELEASE_VERSION=$(curl -s https://releases.quilibrium.com/release | grep -Eo "node-[0-9]+(\.[0-9]+)*-" | head -n 1 | sed 's/node-//;s/-$//')
    set_release_version $RELEASE_VERSION
    echo $RELEASE_VERSION
}

fetch_qclient_release_version() {
    local RELEASE_VERSION=$(curl -s https://releases.quilibrium.com/qclient-release | grep -Eo "qclient-[0-9]+(\.[0-9]+)*-" | head -n 1 | sed 's/qclient-//;s/-$//')
    echo $RELEASE_VERSION
}


set_current_version() {
    current_version="$1" yq -i e '.current_version = strenv(current_version)' $QTOOLS_CONFIG_FILE
}

get_current_version() {
    local CURRENT_VERSION=$(launchctl list | grep $QUIL_SERVICE_NAME | awk '{print $3}' | grep -oP "\-([0-9]+\.)+([0-9]+)\-" | head -n 1 | tr -d 'node-')
    
    set_current_version $CURRENT_VERSION
    echo $CURRENT_VERSION
}

fetch_available_files() {
  local url=$1
  curl -s "$url"
}

get_remote_quil_files() {
    local files=("${!1}")
    local dest_dir=$2

    while IFS= read -r file; do
        if [[ "$file" == *"$OS_ARCH"* ]]; then
            local file_url="https://releases.quilibrium.com/${file}"
            local dest_file="${dest_dir}/${file}"

            if [ ! -f "$dest_file" ]; then
                log "Downloading $file_url to $dest_file"
                curl -o "$dest_file" "$file_url"
            else
                log "File $dest_file already exists"
            fi
        
        fi
    done <<< "$files"
}

set_os_arch() {
    local OS_ARCH="$1"
    yq ".os_arch = \"$OS_ARCH\"" $QTOOLS_CONFIG_FILE
}

get_os_arch() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)

    case "$os" in
        darwin) ;;
        *) echo "Unsupported operating system: $os" >&2; return 1 ;;
    esac

    case "$arch" in
        x86_64|amd64) arch="amd64" ;;
        arm64|aarch64) arch="arm64" ;;
        *) echo "Unsupported architecture: $arch" >&2; return 1 ;;
    esac

    echo "${os}-${arch}"
}

get_versioned_node() {
    local version=$(fetch_release_version)
    local os_arch=$(get_os_arch)
    if [ -z "$version" ] || [ -z "$os_arch" ]; then
        log "Error: Could not determine version or OS architecture"
        return 1
    fi
    echo "node-${version}-${os_arch}"
}

get_versioned_qclient() {
    echo "qclient-$(fetch_qclient_release_version)-$(get_os_arch)"
}

# Add this function to utils.sh
qclient_fn() {
    if [[ "$(yq '.settings.qclient.enabled' "$QTOOLS_CONFIG_FILE")" == "true" ]]; then
        if [[ -f "$QUIL_QCLIENT_BIN" && -x "$QUIL_QCLIENT_BIN" ]]; then
            "$QUIL_QCLIENT_BIN" "$@"
        else
            if [[ ! -f "$QUIL_QCLIENT_BIN" ]]; then
                log "qclient is enabled but the binary is not found at $QUIL_QCLIENT_BIN"
            elif [[ ! -x "$QUIL_QCLIENT_BIN" ]]; then
                log "qclient binary found at $QUIL_QCLIENT_BIN but it is not executable"
            else
                log "Unexpected error with qclient binary at $QUIL_QCLIENT_BIN"
            fi
            return 1
        fi
    else
        log "qclient is not enabled in the configuration"
        return 1
    fi
}