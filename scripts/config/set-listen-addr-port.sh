#!/bin/bash

# Validate port parameter
if [ $# -ne 1 ] || ! [[ $1 =~ ^[0-9]+$ ]]; then
    echo "Error: Please provide a valid port number as parameter"
    exit 1
fi

PORT=$1
shift

echo "Setting listen port to $PORT"

# Check if --proto parameter is provided
while [[ $# -gt 0 ]]; do
    case $1 in
        --proto)
            if [[ -n "$2" && "$2" =~ ^(udp|tcp)$ ]]; then
                LISTEN_MODE="$2"
                qtools config set-value settings.listenAddr.mode "$LISTEN_MODE" --quiet
                echo "Protocol set to $LISTEN_MODE"
            else
                echo "Error: Protocol must be either 'udp' or 'tcp'"
                exit 1
            fi
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done


# Validate port range
if [ $PORT -lt 1 ] || [ $PORT -gt 65535 ]; then
    echo "Error: Port must be between 1 and 65535"
    exit 1
fi

# Update qtools config
qtools config set-value settings.listenAddr.port "$PORT" --quiet

# Update quilibrium config
# Get listen mode from config
LISTEN_MODE=$(yq eval '.settings.listenAddr.mode' $QTOOLS_CONFIG_FILE)

# Validate listen mode
if [ "$LISTEN_MODE" != "udp" ] && [ "$LISTEN_MODE" != "tcp" ]; then
    echo "Error: Listen mode must be either 'udp' or 'tcp'"
    exit 1
fi

# Set protocol suffix based on mode
if [ "$LISTEN_MODE" = "udp" ]; then
    PROTOCOL="/quic-v1"
fi

yq eval -i ".p2p.listenMultiaddr = \"/ip4/0.0.0.0/${LISTEN_MODE}/${PORT}${PROTOCOL}\"" $QUIL_CONFIG_FILE

echo "Listen port updated to $PORT in configuration files"

qtools restart
