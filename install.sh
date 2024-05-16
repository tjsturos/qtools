#!/bin/bash

FILE_AFTER_FIRST_REBOOT="after-first-reboot"
FILE_SETUP_COMPLETE="setup-complete"
FILE_LOG="quil_on_start_log"

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

# "FLAGS" to look for to change what this script will run
export FLAG_AFTER_FIRST_REBOOT=$HOME/$FILE_AFTER_FIRST_REBOOT
export FLAG_SETUP_COMPLETE=$HOME/$FILE_SETUP_COMPLETE

if [ -f "$FLAG_AFTER_FIRST_REBOOT" ]; then
    # this is needed because the after-reboot script will install via cron task
    export CURRENT_DIR=$(cat $FLAG_AFTER_FIRST_REBOOT)
    echo "$(date) - Found existing install directory" >> $CURRENT_DIR/$FILE_LOG
    cd $CURRENT_DIR
else
    # If not set or empty, default to the current working directory
    export CURRENT_DIR=$(pwd)
    echo "$(date) - no existing install directory" >> $CURRENT_DIR/$FILE_LOG
fi

log() {
    if [[ ! -f "$CURRENT_DIR/$FILE_LOG" ]]; then
        touch $CURRENT_DIR/$FILE_LOG
    fi

    echo "$(date) - $1" >> $CURRENT_DIR/$FILE_LOG
}

log "Starting up..."

# this will be used by the after-reboot script
export FILE_SETUP_CUSTOMIZATION="$CURRENT_DIR/scripts/customization.sh"

if [[ ! -f "$FLAG_SETUP_COMPLETE" ]]; then
    log "Setup not complete"
    # if setup is not complete, yet then continue setup
    if [[ ! -f "$FLAG_AFTER_FIRST_REBOOT" ]]; then
        log "before first reboot"
        # if the server hasn't been rebooted for the first time, then run the first-time boot script
        source $CURRENT_DIR/scripts/before-reboot.sh
    else
        log "after first reboot"
        source $CURRENT_DIR/scripts/after-reboot.sh
    fi
else
    # if the setup is already complete, then no need to do again
    # go to repo and start detached docker container
    log "After reboot and setup is complete. Nothing to do."
fi