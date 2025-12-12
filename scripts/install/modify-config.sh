#!/bin/bash
# HELP: Will properly format the node\'s config file.

CONFIG_DIR="$QUIL_NODE_PATH/.config"
FILENAME="config.yml"
CONFIG_FILE=$CONFIG_DIR/$FILENAME

modify_config_file() {
    log "Modifying Ceremony client's config.yml file."

    # Get the listenAddr mode from the qtools config file
    LISTEN_ADDR_MODE=$(yq '.settings.listenAddr.mode' $QTOOLS_CONFIG_FILE)
    GRPC_MULTIADDR="/ip4/127.0.0.1/tcp/8337"
    REST_MULTIADDR="/ip4/127.0.0.1/tcp/8338"

    # Determine the appropriate multiaddr format based on the mode
    if [ "$LISTEN_ADDR_MODE" = "udp" ]; then
        P2P_MULTIADDR="/ip4/0.0.0.0/udp/8336/quic-v1"
    else
        P2P_MULTIADDR="/ip4/0.0.0.0/tcp/8336"
    fi

    # Get the stats enabled setting from the qtools config file
    STATS_ENABLED=$(yq '.settings.statistics.enabled' $QTOOLS_CONFIG_FILE)

    # Determine the statsMultiaddr value based on the stats enabled setting
    STATS_MULTIADDR=$([ "$STATS_ENABLED" = "true" ] && echo "/dns/stats.quilibrium.com/tcp/443" || echo "")

    # Modify the config file using yq
    # Check if file is owned by quilibrium user and use sudo if needed
    # This handles cases where user was just added to quilibrium group
    # but current shell session doesn't have group membership active yet
    local file_owner=$(stat -c '%U' "$CONFIG_FILE" 2>/dev/null || stat -f '%Su' "$CONFIG_FILE" 2>/dev/null || echo "")
    if [ "$file_owner" == "quilibrium" ] && [ "$(whoami)" != "root" ]; then
        sudo yq -i '
            .p2p.listenMultiaddr = "'"$P2P_MULTIADDR"'" |
            .listenGrpcMultiaddr = "'"$GRPC_MULTIADDR"'" |
            .listenRESTMultiaddr = "'"$REST_MULTIADDR"'" |
            .engine.statsMultiaddr = "'"$STATS_MULTIADDR"'"
        ' "$CONFIG_FILE"
    else
        yq -i '
            .p2p.listenMultiaddr = "'"$P2P_MULTIADDR"'" |
            .listenGrpcMultiaddr = "'"$GRPC_MULTIADDR"'" |
            .listenRESTMultiaddr = "'"$REST_MULTIADDR"'" |
            .engine.statsMultiaddr = "'"$STATS_MULTIADDR"'"
        ' "$CONFIG_FILE"
    fi

    log "Config file updated successfully."
}

if [ -f "$CONFIG_FILE" ]; then
    modify_config_file
else
    log "No config file found."
fi

