#!/bin/bash
# HELP: Switches to the next peer configuration in the configured peer list
# PARAM: --frames: Number of frames to wait before switching (default: 10)
# PARAM: --daemon: Run in daemon mode, continuously monitoring frames
# Usage: qtools config-carousel [--frames <num-frames>] [--daemon]

# Check if config needs migration
if ! yq eval '.scheduled_tasks.config_carousel' $QTOOLS_CONFIG_FILE >/dev/null 2>&1; then
    echo "Config needs migration. Running migration..."
    qtools migrate-qtools-config
fi

FRAMES_BEFORE_SWITCH=10
DAEMON_MODE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --frames)
            FRAMES_BEFORE_SWITCH="$2"
            shift 2
            ;;
        --daemon)
            DAEMON_MODE=true
            shift
            ;;
        *)
            echo "Invalid argument: $1"
            exit 1
            ;;
    esac
done

switch_config() {
    # Get the peer list and current index
    PEER_LIST=$(yq eval '.scheduled_tasks.config_carousel.peer_list[]' $QTOOLS_CONFIG_FILE)
    CURRENT_INDEX=$(yq eval '.scheduled_tasks.config_carousel.current_index // 0' $QTOOLS_CONFIG_FILE)
    TOTAL_PEERS=$(echo "$PEER_LIST" | wc -l)

    if [ $TOTAL_PEERS -eq 0 ]; then
        echo "No peer IDs configured in scheduled_tasks.config_carousel.peer_list"
        exit 1
    fi

    # Calculate next index
    NEXT_INDEX=$(( (CURRENT_INDEX + 1) % TOTAL_PEERS ))

    # Get the next peer ID
    NEXT_PEER=$(echo "$PEER_LIST" | sed -n "$((NEXT_INDEX + 1))p")

    if [ -z "$NEXT_PEER" ]; then
        echo "Failed to get next peer ID"
        exit 1
    fi

    # Update the current index in config
    yq -i ".scheduled_tasks.config_carousel.current_index = $NEXT_INDEX" $QTOOLS_CONFIG_FILE

    # Change to the node directory
    cd $QUIL_NODE_PATH || exit 1

    # Restore the peer configuration and restart
    echo "Switching to peer ID: $NEXT_PEER"
    qtools restore-peer --local "$NEXT_PEER"
    qtools restart
}

if [ "$DAEMON_MODE" = true ]; then
    while true; do
        FRAME_COUNT=0
        while [ $FRAME_COUNT -lt $FRAMES_BEFORE_SWITCH ]; do
            # Check if a new frame is available
            if [ -f "$QUIL_NODE_PATH/frame.json" ]; then
                CURRENT_FRAME=$(cat "$QUIL_NODE_PATH/frame.json" | jq -r '.frame // 0')
                if [ "$CURRENT_FRAME" != "$LAST_FRAME" ]; then
                    FRAME_COUNT=$((FRAME_COUNT + 1))
                    LAST_FRAME=$CURRENT_FRAME
                    echo "Frame count: $FRAME_COUNT/$FRAMES_BEFORE_SWITCH"
                fi
            fi
            sleep 5
        done
        switch_config
    done
else
    switch_config
fi 