#!/bin/bash
BACKUP_DIR=~/quil-backup
RESTORE_DIR=$QUIL_NODE_PATH/.config

restore_file_from_backup() {
    FILENAME="$1"
    cp $BACKUP_DIR/$FILENAME $RESTORE_DIR
    file_exists $RESTORE_DIR/$FILENAME
}

restore_backup() {
    FILENAME="$1"
    if [ ! -f "$RESTORE_DIR/$FILENAME" ]; then
        # Monitor the directory for creation events
        inotifywait -m -e create --format '%f' "$MONITOR_DIR" | while read NEW_FILE
        do
            if [ "$NEW_FILE" == "$FILENAME" ]; then
                systemctl stop ceremonyclient.service
                restore_file_from_backup $FILENAME
            fi
        done

    else
        systemctl stop ceremonyclient.service
        restore_file_from_backup $FILENAME
        systemctl start ceremonyclient.service
    fi
}

# Wait for the directory to be created if it doesn't exist
if [ ! -d "$RESTORE_DIR" ]; then
    wait_for_directory $RESTORE_DIR
fi

restore_backup "keys.yml" &
restore_backup "config.yml" &

wait 

systemctl start ceremonyclient.service
