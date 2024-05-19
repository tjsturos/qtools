#!/bin/bash

# Directory to monitor
MONITOR_DIR="$QUIL_NODE_PATH/.config"

# Filename to watch for
FILENAME="config.yml"

# Ensure inotify-tools is installed
if ! command -v inotifywait &> /dev/null
then
    log "inotifywait could not be found, please install inotify-tools"
    exit 1
fi

# Modifications to make to the config file
modify_config_file() {
    echo "Modifying config"
    sed -i 's/^ *listenGrpcMultiaddr:.*$/  listenGrpcMultiaddr: \/ip4\/127.0.0.1\/tcp\/8337/' $MONITOR_DIR/$FILENAME
    sed -i 's/^ *listenRESTMultiaddr:.*$/  listenGrpcMultiaddr: \/ip4\/127.0.0.1\/tcp\/8338/' $MONITOR_DIR/$FILENAME
    sed -i '/^ *engine: *$/a \  statsMultiaddr: "/dns/stats.quilibrium.com/tcp/443"' $MONITOR_DIR/$FILENAME
}

# Wait for the directory to be created if it doesn't exist
if [ ! -d "$MONITOR_DIR" ]; then
    wait_for_directory $MONITOR_DIR
fi


if [ ! -f "$MONITOR_DIR/$FILENAME" ]; then
    # Monitor the directory for creation events
    inotifywait -m -e create --format '%f' "$MONITOR_DIR" | while read NEW_FILE
    do
        if [ "$NEW_FILE" == "$FILENAME" ]; then
            echo "File '$FILENAME' has been created in directory '$MONITOR_DIR'."
            systemctl stop ceremonyclient.service
            modify_config_file
            systemctl start ceremonyclient.service
        fi
    done

else
    systemctl stop ceremonyclient.service
    modify_config_file
    systemctl start ceremonyclient.service
fi