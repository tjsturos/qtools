#!/bin/bash
# HELP: Will properly format the node\'s config file.

CONFIG_DIR="$QUIL_NODE_PATH/.config"

# Filename to watch for
FILENAME="config.yml"

CONFIG_FILE=$CONFIG_DIR/$FILENAME

# Modifications to make to the config file
modify_config_file() {
    log "Modifying Ceremony client's config.yml file."

    # Get the listenAddr mode from the config file
    LISTEN_ADDR_MODE=$(yq '.settings.listenAddr.mode' $QTOOLS_CONFIG_FILE)

    # Determine the appropriate multiaddr format based on the mode
    if [ "$LISTEN_ADDR_MODE" = "udp" ]; then
        P2P_MULTIADDR="\/ip4\/127.0.0.1\/udp\/8336\/quic-v1"
        GRPC_MULTIADDR="\/ip4\/127.0.0.1\/udp\/8337\/quic-v1"
        REST_MULTIADDR="\/ip4\/127.0.0.1\/udp\/8338\/quic-v1"
    else
        P2P_MULTIADDR="\/ip4\/127.0.0.1\/tcp\/8336"
        GRPC_MULTIADDR="\/ip4\/127.0.0.1\/tcp\/8337"
        REST_MULTIADDR="\/ip4\/127.0.0.1\/tcp\/8338"
    fi

    # Check and modify listenMultiaddr under p2p
    if ! grep -q "^  listenMultiaddr: $P2P_MULTIADDR" "$CONFIG_FILE"; then
        sed -i "/^ *p2p:/,/^[^ ]/ s/^ *listenMultiaddr:.*$/  listenMultiaddr: $P2P_MULTIADDR/" "$CONFIG_FILE"
    fi

    # Check and modify listenGrpcMultiaddr
    if ! grep -q "^listenGrpcMultiaddr: $GRPC_MULTIADDR" "$CONFIG_FILE"; then
        sed -i "s/^listenGrpcMultiaddr:.*$/listenGrpcMultiaddr: $GRPC_MULTIADDR/" "$CONFIG_FILE"
    fi

    # Check and modify listenRESTMultiaddr
    if ! grep -q "^listenRESTMultiaddr: $REST_MULTIADDR" "$CONFIG_FILE"; then
        sed -i "s/^listenRESTMultiaddr:.*$/listenRESTMultiaddr: $REST_MULTIADDR/" "$CONFIG_FILE"
    fi

    # Check if statsMultiaddr is within the engine section and update or add it
    # Get the stats enabled setting from the qtools config file
    STATS_ENABLED=$(yq '.settings.statistics.enabled' $QTOOLS_CONFIG_FILE)

    # Determine the statsMultiaddr value based on the stats enabled setting
    if [ "$STATS_ENABLED" = "true" ]; then
        STATS_MULTIADDR="/dns/stats.quilibrium.com/tcp/443"
    else
        STATS_MULTIADDR=""
    fi

    # Use awk to update or add the statsMultiaddr in the config file
    awk -v stats_multiaddr="$STATS_MULTIADDR" '
    /^ *engine: *$/ {in_engine=1; print; next}
    /^ *[^ ]/ {in_engine=0}
    in_engine && /statsMultiaddr:/ {found=1; $0="  statsMultiaddr: \"" stats_multiaddr "\""}
    {print}
    END {
        if (in_engine && !found && stats_multiaddr != "") {
            print "  statsMultiaddr: \"" stats_multiaddr "\""
        }
    }
    ' "$CONFIG_FILE"
}

if [ -f $CONFIG_FILE ]; then
    modify_config_file
else 
    log "No config file found."
fi

