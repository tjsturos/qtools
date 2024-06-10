
log() {
    MESSAGE="$1"
    SHOULD_OUTPUT="${2:-true}"

    if [[ ! -f "$QTOOLS_PATH/$FILE_LOG" ]]; then
        touch $QTOOLS_PATH/$LOG_OUTPUT_FILE
    fi

    LOG="$(date) - $1"
    if [ "$SHOULD_OUTPUT" != "false" ]; then
            echo "$LOG"
    fi

    echo "$LOG" >> $QTOOLS_PATH/$LOG_OUTPUT_FILE
}

append_to_file() {
    FILE="$1"
    CONTENT="$2"
    LOG_OUTPUT="${3:-true}"

    if ! grep -qFx "$CONTENT" $FILE 2>/dev/null; then
        
        log "Adding $CONTENT to $FILE" $LOG_OUTPUT
        
        echo "$CONTENT" >> $FILE
    else
        log "$CONTENT already found in $FILE. Skipping." $LOG_OUTPUT
    fi
}

remove_directory() {
    DIRECTORY="$1"
    LOG_OUTPUT="${2:-true}"
    if [ -d "$DIRECTORY" ]; then
        log "Directory $DIRECTORY found.  Removing." $LOG_OUTPUT
        
        rm -rf $DIRECTORY
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
        
        rm $FILE
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

# Function to monitor for the directory creation
wait_for_directory() {
    DIRECTORY="$1"
    while [ ! -d "$DIRECTORY" ]; do
        log "Waiting for directory '$DIRECTORY' to be created..."
        sleep 2
    done
    log "Directory '$DIRECTORY' has been created."
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
    sed -i "/$pattern/d" "$file"
}

get_versioned_binary() {
    # Extract version information
    local VERSION=$(cat $QUIL_NODE_PATH/config/version.go | grep -A 1 "func GetVersion() \[\]byte {" | grep -Eo '0x[0-9a-fA-F]+' | xargs printf "%d.%d.%d")

    # Determine the binary path based on OS and architecture
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [[ "$arch" == arm* ]]; then
            QUIL_BIN="node-$VERSION-linux-arm64"
        else
            QUIL_BIN="node-$VERSION-linux-amd64"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        QUIL_BIN="node-$VERSION-darwin-arm64"
    else
        log "Unsupported OS for releases, please build from source."
        exit 1
    fi

    echo "$QUIL_BIN"
}

get_processor_count() {
    echo "$(grep -c ^processor /proc/cpuinfo)"
}
