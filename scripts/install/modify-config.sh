#!/bin/bash

# Directory to monitor
MONITOR_DIR="$QUIL_NODE_PATH/.config"

# Filename to watch for
FILENAME="config.yml"

# Ensure inotify-tools is installed
if ! command -v inotifywait &> /dev/null
then
    log "The binary inotifywait could not be found, please install inotify-tools"
    exit 1
fi

# Modifications to make to the config file
modify_config_file() {
    log "Modifying Ceremony client's config.yml file."

    # Check and modify listenGrpcMultiaddr
    if ! grep -q '^ *listenGrpcMultiaddr: \/ip4\/127.0.0.1\/tcp\/8337' "$MONITOR_DIR/$FILENAME"; then
        sed -i 's/^ *listenGrpcMultiaddr:.*$/  listenGrpcMultiaddr: \/ip4\/127.0.0.1\/tcp\/8337/' "$MONITOR_DIR/$FILENAME"
    fi

    # Check and modify listenRESTMultiaddr
    if ! grep -q '^ *listenRESTMultiaddr: \/ip4\/127.0.0.1\/tcp\/8338' "$MONITOR_DIR/$FILENAME"; then
        sed -i 's/^ *listenRESTMultiaddr:.*$/  listenRESTMultiaddr: \/ip4\/127.0.0.1\/tcp\/8338/' "$MONITOR_DIR/$FILENAME"
    fi

    # Check if statsMultiaddr is within the engine section and update or add it
    awk -i inplace '
    /^ *engine: *$/ {in_engine=1; print; next}
    /^ *[^ ]/ {in_engine=0}
    in_engine && /statsMultiaddr:/ {found=1; $0="  statsMultiaddr: \"/dns/stats.quilibrium.com/tcp/443\""}
    {print}
    END {
        if (in_engine && !found) {
            print "  statsMultiaddr: \"/dns/stats.quilibrium.com/tcp/443\""
        }
    }
    ' "$MONITOR_DIR/$FILENAME"
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
            log "File '$FILENAME' has been created in directory '$MONITOR_DIR'."
            qtools stop
            modify_config_file
            qtools start
        fi
    done

else
    qtools stop
    modify_config_file
    qtools start
fi