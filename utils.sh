
log() {
    FILE_LOG="quil-node-setup.log"
    if [[ ! -f "$QTOOLS_PATH/$FILE_LOG" ]]; then
        touch $QTOOLS_PATH/$FILE_LOG
    fi

    LOG="$(date) - $1"
    echo "$LOG" >> $QTOOLS_PATH/$FILE_LOG
    echo "$LOG"
}

append_to_file() {
    FILE="$1"
    CONTENT="$2"

    if ! grep -qFx "$CONTENT" $FILE; then
        log "Adding $CONTENT to $FILE"
        echo "$CONTENT" >> $FILE
    else
        log "$CONTENT already found in $FILE. Skipping."
    fi
}

remove_directory() {
    DIRECTORY="$1"
    if [ -d "$DIRECTORY" ]; then
        log "Directory $DIRECTORY found.  Removing."
        rm -rf $DIRECTORY
        if [ ! -f $DIRECTORY ]; then
            log "Directory $DIRECTORY deletion was successful."
        else
            log "Directory $DIRECTORY deletion was not successful."
        fi
    fi
}

remove_file() {
    FILE="$1"
    if [ -f "$FILE" ]; then
        log "File $FILE found.  Removing."
        rm $FILE
        if [ ! -f $FILE ]; then
            log "File $FILE deletion was successful."
        else
            log "File $FILE deletion was not successful."
        fi
    else
        log "$FILE file not found."
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
    package_parent="$2"
    if ! command_exists $package_parent; then
        log "$package is not installed. Installing..."

        # Detect the package manager and install the package
        if command_exists apt-get; then
            sudo apt-get update -y
            sudo apt-get install -y -q $package
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
        if command_exists $package; then
            log "$package was successfuly installed."
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