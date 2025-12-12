BLUE="\e[34m"
INFO_ICON="\u2139"
RESET="\e[0m"
RED="\e[31m"
WARNING_ICON="\u26A0"
GREEN="\e[32m"
CHECK_ICON="✓"
YELLOW="\e[33m"

if ! command -v yq &> /dev/null; then
    source $QTOOLS_PATH/scripts/install/install-yq.sh
    source ~/.bashrc
fi

log() {
    MESSAGE="$1"
    SHOULD_OUTPUT="${2:-true}"

    if [ -z "$LOG_OUTPUT_PATH" ]; then
        LOG_OUTPUT_FILE=$(yq '.settings.log_file' $QTOOLS_CONFIG_FILE)
    fi

    if [[ ! -f "$QTOOLS_PATH/$FILE_LOG" ]]; then
        touch $QTOOLS_PATH/$LOG_OUTPUT_FILE
    fi

    LOG="$(date) - $1"
    if [ "$SHOULD_OUTPUT" != "false" ]; then
            echo "$LOG"
    fi

    echo "$LOG" >> "$QTOOLS_PATH/$LOG_OUTPUT_FILE"
}

# Function to log command execution
log_command_execution() {
    local COMMAND="$1"
    shift
    local PARAMS=("$@")

    # Log file path: qtools/log file
    local LOG_FILE="$QTOOLS_PATH/log"

    # Ensure log file exists
    touch "$LOG_FILE"

    # Format: timestamp - command [params] [via <describe>]
    local TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    local LOG_ENTRY="$TIMESTAMP - $COMMAND"

    # Add parameters if any
    if [ ${#PARAMS[@]} -gt 0 ]; then
        LOG_ENTRY="$LOG_ENTRY ${PARAMS[*]}"
    fi

    # Add describe label if set (from environment variable)
    if [ -n "$QTOOLS_DESCRIBE" ]; then
        LOG_ENTRY="$LOG_ENTRY via $QTOOLS_DESCRIBE"
    fi

    # Append to log file
    echo "$LOG_ENTRY" >> "$LOG_FILE"
}

get_local_ip() {
    local servers=$(yq eval '.service.clustering.servers' $QTOOLS_CONFIG_FILE)
    local server_count=$(echo "$servers" | yq eval '. | length' -)
    local local_ips=$(hostname -I)

    for ((i=0; i<server_count; i++)); do
        local server=$(echo "$servers" | yq eval ".[$i]" -)
        local ip=$(echo "$server" | yq eval '.ip' -)

        if echo "$local_ips" | grep -q "$ip" || echo "$ip" | grep -q "127.0.0.1"; then
            echo "$ip"
            return
        fi
    done


}

is_master() {
    local is_clustering_enabled=$(yq eval '.service.clustering.enabled' $QTOOLS_CONFIG_FILE)
    if [ "$is_clustering_enabled" == "true" ]; then
        local main_ip=$(yq eval '.service.clustering.main_ip' $QTOOLS_CONFIG_FILE)
        local local_ip=$(get_local_ip)
        if [ "$main_ip" == "$local_ip" ]; then
            echo "true"
        else
            echo "false"
        fi
    else
        echo "false"
    fi
}

get_last_started_at() {
    echo "$(echo "$(sudo systemctl status $QUIL_SERVICE_NAME)" | grep -oP '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}' -m1)"
}

is_app_finished_starting() {
    local UPTIME="$(get_last_started_at)"
    local PEER_TEXT=$(sudo journalctl -u $QUIL_SERVICE_NAME --no-hostname -S "${UPTIME}" | grep 'peers in store')
    if [ -z "$PEER_TEXT" ]; then
        echo "false"
    else
        echo "true"
    fi
}

append_to_file() {
    FILE="$1"
    CONTENT="$2"
    LOG_OUTPUT="${3:-true}"

    if ! grep -qFx "$CONTENT" $FILE 2>/dev/null; then

        log "Adding $CONTENT to $FILE" $LOG_OUTPUT

        sudo -- sh -c "echo \"$CONTENT\" >> $FILE"
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

run_node_command() {
    cd $QUIL_NODE_PATH

    SIGNATURE_CHECK=""
    TESTNET=""
    DEBUG=""

    if [ "$(yq '.service.signature_check' $QTOOLS_CONFIG_FILE)" == "false" ]; then
        SIGNATURE_CHECK=" --signature-check=false"
    fi

    if [ "$(yq '.service.testnet // "false"' $QTOOLS_CONFIG_FILE)" == "true" ]; then
        TESTNET=" --network=1"
    fi

    if [ "$(yq '.service.debug // "false"' $QTOOLS_CONFIG_FILE)" == "true" ]; then
        DEBUG=" --debug"
    fi

    # Filter out --print-cmd from arguments
    FILTERED_ARGS=()
    while [[ $# -gt 0 ]]; do
        if [[ "$1" == "--print-cmd" ]]; then

            echo "Command: $LINKED_NODE_BINARY$SIGNATURE_CHECK$TESTNET$DEBUG $@"
            echo "Signature Check:$SIGNATURE_CHECK"
            echo "Testnet:$TESTNET"
            echo "Debug:$DEBUG"
            shift
        else
            FILTERED_ARGS+=("$1")
            shift
        fi

    done
    set -- "${FILTERED_ARGS[@]}"

    $LINKED_NODE_BINARY$SIGNATURE_CHECK$TESTNET$DEBUG "$@"
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

        # Detect the package manager and install the package
        if command_exists apt-get; then
            sudo apt-get update -y &> $QTOOLS_PATH/$LOG_OUTPUT_FILE
            sudo apt-get install -y -q $package  &> $QTOOLS_PATH/$LOG_OUTPUT_FILE
        elif command_exists yum; then
            sudo yum install -y $package
        elif command_exists dnf; then
            sudo dnf install -y $package
        elif command_exists pacman; then
            sudo pacman -Sy $package
        elif command_exists brew; then
            brew install $package
        else
            log "Error: Cannot determine the package manager to use for installing $package."
            exit 1
        fi

        # Verify if the installation was successful
        if command_exists $command; then
            log "$package was successfuly installed and $command is now available for use."
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

    # Use sed to remove lines matching the specified pattern
    sudo sed -i "/$pattern/d" "$file"
}

set_release_version() {
    new_version="$1" yq -i e '.release_version = strenv(new_version)' $QTOOLS_CONFIG_FILE
}

set_release_qclient_version() {
    new_version="$1" yq -i e '.release_qclient_version = strenv(new_version)' $QTOOLS_CONFIG_FILE
}

fetch_node_release_version() {
    local RELEASE_VERSION="$(curl -s https://releases.quilibrium.com/release | grep -oP "\-([0-9]+\.?)+\-" | head -n 1 | tr -d 'node-')"
    set_release_version $RELEASE_VERSION
    echo $RELEASE_VERSION
}

fetch_qclient_release_version() {
    local RELEASE_VERSION="$(curl -s https://releases.quilibrium.com/qclient-release | grep -oP "\-([0-9]+\.?)+\-" | head -n 1 | tr -d 'qclient-')"
    set_release_qclient_version $RELEASE_VERSION
    echo $RELEASE_VERSION
}

set_current_node_version() {
    local current_version="$1"
    yq -i e ".current_node_version = \"$current_version\"" $QTOOLS_CONFIG_FILE
}

set_current_qclient_version() {
    local current_version="$1"
    yq -i e ".current_qclient_version = \"$current_version\"" $QTOOLS_CONFIG_FILE
}

get_current_node_version() {
    local CONFIG_VERSION="$(yq eval '.current_node_version' $QTOOLS_CONFIG_FILE)"
    local LINKED_BINARY_NAME=$(readlink -f "$LINKED_NODE_BINARY")
    local SYMLINK_VERSION=""

    if [[ -n "$LINKED_BINARY_NAME" ]]; then
        SYMLINK_VERSION=$(basename "$LINKED_BINARY_NAME" | grep -oP "node-\K([0-9]+\.?)+")
    fi

    # If both are empty, return a safe default
    if [[ -z "$CONFIG_VERSION" && -z "$SYMLINK_VERSION" ]]; then
        echo "0.0.0"
        return
    fi

    # Prefer the symlinked version when available; persist to config if it differs
    if [[ -n "$SYMLINK_VERSION" ]]; then
        if [[ "$SYMLINK_VERSION" != "$CONFIG_VERSION" ]]; then
            set_current_node_version "$SYMLINK_VERSION"
        fi
        echo "$SYMLINK_VERSION"
        return
    fi

    echo "$CONFIG_VERSION"
}

get_current_qclient_version() {
    local CURRENT_VERSION="$(yq eval '.current_qclient_version' $QTOOLS_CONFIG_FILE)"
    if [ -z "$CURRENT_VERSION" ]; then
        # Get the version from the symlinked binary
        local LINKED_BINARY_NAME=$(readlink -f "$LINKED_QCLIENT_BINARY")
        if [[ -n "$LINKED_BINARY_NAME" ]]; then
            CURRENT_VERSION=$(basename "$LINKED_BINARY_NAME" | grep -oP "qclient-\K([0-9]+\.?)+")
            if [[ -z "$CURRENT_VERSION" ]]; then
                CURRENT_VERSION="0.0.0"
            fi
        else
            CURRENT_VERSION="0.0.0"
        fi
        set_current_qclient_version $CURRENT_VERSION
    fi
    echo $CURRENT_VERSION
}

fetch_available_files() {
  local url=$1
  curl -s "$url"
}

get_remote_quil_files() {
    local files=("${!1}")
    local dest_dir=$2

    # Ensure destination directory exists (may be run as root)
    sudo mkdir -p "$dest_dir"

    # Check if we should set ownership for quilibrium user
    SERVICE_USER=$(yq '.service.default_user // "quilibrium"' $QTOOLS_CONFIG_FILE 2>/dev/null || echo "quilibrium")
    SET_OWNERSHIP=false
    if [ "$SERVICE_USER" == "quilibrium" ] && id "quilibrium" &>/dev/null; then
        SET_OWNERSHIP=true
        # Ensure quilibrium user owns the directory and can write to it
        sudo chown -R quilibrium:quilibrium "$dest_dir" 2>/dev/null || true
        # Ensure quilibrium user and group can write to the directory
        sudo chmod -R ug+w "$dest_dir" 2>/dev/null || true
    fi

    while IFS= read -r file; do
        if [[ "$file" == *"$OS_ARCH"* ]]; then
            local file_url="https://releases.quilibrium.com/${file}"
            local dest_file="${dest_dir}/${file}"

            if [ ! -f "$dest_file" ]; then
                log "Downloading $file_url to $dest_file"
                # Use sudo if we're setting ownership for quilibrium user
                if [ "$SET_OWNERSHIP" == "true" ]; then
                    sudo curl -o "$dest_file" "$file_url"
                    sudo chown quilibrium:quilibrium "$dest_file" 2>/dev/null || true
                    sudo chmod +x "$dest_file" 2>/dev/null || true
                else
                    curl -o "$dest_file" "$file_url"
                fi
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
        linux|darwin) ;;
        *) echo "Unsupported operating system: $os" >&2; return 1 ;;
    esac

    case "$arch" in
        x86_64|amd64) arch="amd64" ;;
        arm64|aarch64) arch="arm64" ;;
        *) echo "Unsupported architecture: $arch" >&2; return 1 ;;
    esac

    echo "${os}-${arch}"
}

get_release_node_version() {
    echo "node-$(fetch_node_release_version)-$(get_os_arch)"
}

get_current_versioned_node() {
    echo "node-$(get_current_node_version)-$(get_os_arch)"
}

get_current_versioned_qclient() {
    echo "qclient-$(get_current_qclient_version)-$(get_os_arch)"
}

get_versioned_qclient() {
    echo "qclient-$(fetch_qclient_release_version)-$(get_os_arch)"
}

check_yq() {
    if ! command -v yq &> /dev/null; then
        echo "Error: yq is not installed. Please install yq to continue."
        exit 1
    fi
    return 0
}

# Helper function to safely check if a file exists (handles quilibrium-owned files)
# Returns 0 if file exists, 1 if it doesn't
safe_file_exists() {
    local file_path="$1"
    # Try normal check first
    if [ -f "$file_path" ]; then
        return 0
    fi
    # File might exist but be owned by quilibrium user - check with sudo
    if sudo test -f "$file_path" 2>/dev/null; then
        return 0
    fi
    return 1
}

# Helper function to safely modify config files that might be owned by quilibrium user
# This handles the case where the user was just added to the quilibrium group
# but the current shell session doesn't have the group membership active yet
safe_yq_write() {
    local config_file="$1"
    shift
    local yq_command="$@"

    # Check if file exists and is owned by quilibrium user
    if [ -f "$config_file" ]; then
        local file_owner=$(stat -c '%U' "$config_file" 2>/dev/null || stat -f '%Su' "$config_file" 2>/dev/null || echo "")
        if [ "$file_owner" == "quilibrium" ] && [ "$(whoami)" != "root" ]; then
            # File is owned by quilibrium and we're not root, use sudo
            # This handles cases where group membership isn't active in current shell
            sudo yq -i $yq_command "$config_file"
        else
            # File not owned by quilibrium or we're root, write normally
            yq -i $yq_command "$config_file"
        fi
    else
        # File doesn't exist yet, try normal write first
        if ! yq -i $yq_command "$config_file" 2>/dev/null; then
            # If that failed and parent directory might be owned by quilibrium, try sudo
            local parent_dir=$(dirname "$config_file")
            local dir_owner=$(stat -c '%U' "$parent_dir" 2>/dev/null || stat -f '%Su' "$parent_dir" 2>/dev/null || echo "")
            if [ "$dir_owner" == "quilibrium" ] && [ "$(whoami)" != "root" ]; then
                sudo yq -i $yq_command "$config_file"
            else
                yq -i $yq_command "$config_file"
            fi
        fi
    fi
}

get_public_ip() {
    wget -qO- https://ipecho.net/plain ; echo
}

# Source the hardware utils
source $QTOOLS_PATH/utils/hardware.sh

# Source the snapshot utils (requires hardware.sh)
source $QTOOLS_PATH/utils/snapshot.sh

