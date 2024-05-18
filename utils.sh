
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

remove_file() {
    FILE="$1"
    if [ -f "$FILE" ]; then
        log "File $FILE found.  Removing."
        rm $FILE
        if [ ! -f $FILE ];
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
    if [ ! -f $FILE ];
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
