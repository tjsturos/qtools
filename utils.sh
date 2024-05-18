
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

install_inotify() {
    # Function to check if a command exists

# Check if inotifywait (part of inotify-tools) is installed
if command_exists inotifywait; then
  echo "inotify-tools is already installed."
else
  echo "inotify-tools is not installed. Installing..."

  # Detect the package manager and install inotify-tools
  if command_exists apt-get; then
    sudo apt-get update
    sudo apt-get install -y inotify-tools
  elif command_exists yum; then
    sudo yum install -y inotify-tools
  elif command_exists dnf; then
    sudo dnf install -y inotify-tools
  elif command_exists pacman; then
    sudo pacman -Sy inotify-tools
  elif command_exists brew; then
    brew install inotify-tools
  else
    echo "Error: Cannot determine the package manager to use for installing inotify-tools."
    exit 1
  fi

  # Verify if the installation was successful
  if command_exists inotifywait; then
    echo "inotify-tools was successfully installed."
  else
    echo "Error: Failed to install inotify-tools."
    exit 1
  fi
fi
}