#!/bin/bash
# HELP: Set the gRPC listen multiaddr in the node's config file.
# PARAM: --port <port-int> - The port number (optional, defaults to 8337)
# PARAM: --proto <udp|tcp> - The protocol (optional, defaults to tcp)
# PARAM: --ip <ip-address> - The IP address (optional, defaults to 127.0.0.1)

PORT="8337"
PROTO="tcp"
IP="127.0.0.1"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --port)
            if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
                PORT="$2"
                shift 2
            else
                echo "Error: --port requires a valid port number"
                exit 1
            fi
            ;;
        --proto)
            if [[ -n "$2" && "$2" =~ ^(udp|tcp)$ ]]; then
                PROTO="$2"
                shift 2
            else
                echo "Error: --proto must be either 'udp' or 'tcp'"
                exit 1
            fi
            ;;
        --ip)
            if [[ -n "$2" ]]; then
                IP="$2"
                shift 2
            else
                echo "Error: --ip requires an IP address"
                exit 1
            fi
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: qtools set-grpc-multiaddr [--port <port>] [--proto <udp|tcp>] [--ip <ip>]"
            exit 1
            ;;
    esac
done

# Use defaults if not provided

# Validate port range
if [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
    echo "Error: Port must be between 1 and 65535"
    exit 1
fi

# Check if QUIL config file exists
if [ ! -f "$QUIL_CONFIG_FILE" ]; then
    echo "Error: QUIL config file not found at $QUIL_CONFIG_FILE"
    exit 1
fi

# Build multiaddr
if [ "$PROTO" = "udp" ]; then
    GRPC_MULTIADDR="/ip4/${IP}/udp/${PORT}/quic-v1"
else
    GRPC_MULTIADDR="/ip4/${IP}/tcp/${PORT}"
fi

# Check if file is owned by quilibrium user and use sudo if needed
# This handles cases where user was just added to quilibrium group
# but current shell session doesn't have group membership active yet
file_owner=$(stat -c '%U' "$QUIL_CONFIG_FILE" 2>/dev/null || stat -f '%Su' "$QUIL_CONFIG_FILE" 2>/dev/null || echo "")
if [ "$file_owner" == "quilibrium" ] && [ "$(whoami)" != "root" ]; then
    sudo yq -i '.listenGrpcMultiaddr = "'"$GRPC_MULTIADDR"'"' "$QUIL_CONFIG_FILE"
else
    yq -i '.listenGrpcMultiaddr = "'"$GRPC_MULTIADDR"'"' "$QUIL_CONFIG_FILE"
fi

echo "gRPC listen multiaddr updated to: $GRPC_MULTIADDR"
