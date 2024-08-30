#!/bin/bash
# HELP: Will properly format the node's config file.

CONFIG_DIR="$QUIL_NODE_PATH/.config"
FILENAME="config.yml"
CONFIG_FILE="$CONFIG_DIR/$FILENAME"

# Modifications to make to the config file
modify_config_file() {
    log "Modifying Ceremony client's config.yml file."

    # Ensure the config directory exists
    mkdir -p "$CONFIG_DIR"

    # If the config file doesn't exist, create an empty YAML file
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "---" > "$CONFIG_FILE"
        log "Created new config file at $CONFIG_FILE"
    fi

    # Update listenGrpcMultiaddr
    yq -i '.listenGrpcMultiaddr = "/ip4/127.0.0.1/tcp/8337"' "$CONFIG_FILE"

    # Update listenRESTMultiaddr
    yq -i '.listenRESTMultiaddr = "/ip4/127.0.0.1/tcp/8338"' "$CONFIG_FILE"

    # Update p2p.listenMultiaddr
    yq -i '.p2p.listenMultiaddr = "/ip4/127.0.0.1/tcp/8336"' "$CONFIG_FILE"

    # Update or add statsMultiaddr in the engine section
    yq -i '.engine.statsMultiaddr = "/dns/stats.quilibrium.com/tcp/443"' "$CONFIG_FILE"

    log "Config file updated successfully."
}

if [[ -f "$CONFIG_FILE" ]]; then
    modify_config_file
else 
    log "No config file found at $CONFIG_FILE. Creating a new one."
    modify_config_file
fi

