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

fetch_release_version() {
    local RELEASE_VERSION="$(curl -s https://releases.quilibrium.com/release | grep -oP "\-([0-9]+\.?)+\-" | head -n 1 | tr -d 'node-')"
    set_release_version $RELEASE_VERSION
    echo $RELEASE_VERSION
}

fetch_qclient_release_version() {
    local RELEASE_VERSION="$(curl -s https://releases.quilibrium.com/qclient-release | grep -oP "\-([0-9]+\.?)+\-" | head -n 1 | tr -d 'qclient-')"
    echo $RELEASE_VERSION
}

set_current_version() {
    current_version="$1" yq -i e '.current_version = strenv(current_version)' $QTOOLS_CONFIG_FILE
}

get_current_version() {
    local CURRENT_VERSION=$(systemctl status $QUIL_SERVICE_NAME --no-pager | grep -oP "\-([0-9]+\.)+([0-9]+)\-" | head -n 1 | tr -d 'node-')
    
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
    echo "node-$(fetch_release_version)-$(get_os_arch)"
}

get_current_versioned_node() {
    echo "node-$(get_current_version)-$(get_os_arch)"
}

get_versioned_qclient() {
    echo "qclient-$(fetch_qclient_release_version)-$(get_os_arch)"
}

# Source the hardware utils
source $QTOOLS_PATH/utils/hardware.sh

# Source the snapshot utils (requires hardware.sh)
source $QTOOLS_PATH/utils/snapshot.sh

