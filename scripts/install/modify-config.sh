#!/bin/bash
# HELP: Will properly format the node\'s config file.

modify_config_file() {
    log "Modifying Ceremony client's config.yml file."

    # Get the listenAddr mode from the qtools config file
    LISTEN_ADDR_MODE=$(yq '.settings.listenAddr.mode' $QTOOLS_CONFIG_FILE)

    # Validate listen mode, default to tcp if not set or invalid
    if [ "$LISTEN_ADDR_MODE" != "udp" ] && [ "$LISTEN_ADDR_MODE" != "tcp" ]; then
        LISTEN_ADDR_MODE="tcp"
    fi

    # Set P2P listen multiaddr (port defaults to 8336, proto defaults to tcp)
    qtools --describe "modify-config" set-p2p-listen-multiaddr --port 8336 --proto "$LISTEN_ADDR_MODE"

    # Set gRPC listen multiaddr (port defaults to 8337)
    qtools --describe "modify-config" set-grpc-multiaddr

    # Set REST listen multiaddr (port defaults to 8338)
    qtools --describe "modify-config" set-rest-multiaddr

    # Get the stats enabled setting from the qtools config file
    STATS_ENABLED=$(yq '.settings.statistics.enabled' $QTOOLS_CONFIG_FILE)

    # Set stats multiaddr based on enabled setting
    if [ "$STATS_ENABLED" = "true" ]; then
        qtools --describe "modify-config" set-stats-multiaddr --enable --url "/dns/stats.quilibrium.com/tcp/443"
    else
        qtools --describe "modify-config" set-stats-multiaddr --disable
    fi

    log "Config file updated successfully."
}

if [ -f "$QUIL_CONFIG_FILE" ]; then
    modify_config_file
else
    log "No config file found."
fi

