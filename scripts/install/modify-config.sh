#!/bin/bash
# HELP: Will properly format the node's config file.

CONFIG_DIR="$QUIL_NODE_PATH/.config"

# Filename to watch for
FILENAME="config.yml"

CONFIG_FILE=$CONFIG_DIR/$FILENAME

# Modifications to make to the config file
modify_config_file() {
    log "Modifying Ceremony client's config.yml file."

    # Check and modify listenGrpcMultiaddr
    if ! grep -q '^listenGrpcMultiaddr: \/ip4\/127.0.0.1\/tcp\/8337' "$CONFIG_FILE"; then
        sed -i 's/^listenGrpcMultiaddr:.*$/listenGrpcMultiaddr: \/ip4\/127.0.0.1\/tcp\/8337/' "$CONFIG_FILE"
    fi

    # Check and modify listenRESTMultiaddr
    if ! grep -q '^listenRESTMultiaddr: \/ip4\/127.0.0.1\/tcp\/8338' "$CONFIG_FILE"; then
        sed -i 's/^listenRESTMultiaddr:.*$/listenRESTMultiaddr: \/ip4\/127.0.0.1\/tcp\/8338/' "$CONFIG_FILE"
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
    ' "$CONFIG_FILE"
}

if [ -f $CONFIG_FILE ]; then
    modify_config_file
else 
    log "No config file found."
fi

