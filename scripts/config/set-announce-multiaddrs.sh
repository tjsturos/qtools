#!/bin/bash
# HELP: Set public IP announce multiaddrs in QUIL config
# PARAM: --public-ip <ip_address> - The public IP address to use for announce multiaddrs
# PARAM: --workers <int> - Optional: Number of workers (overrides config value)

PUBLIC_IP=""
WORKER_COUNT_OVERRIDE=""
DRY_RUN="false"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --public-ip)
            if [[ -n "$2" ]]; then
                PUBLIC_IP="$2"
                shift 2
            else
                echo "Error: --public-ip requires an IP address"
                exit 1
            fi
            ;;
        --workers)
            if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
                WORKER_COUNT_OVERRIDE="$2"
                shift 2
            else
                echo "Error: --workers requires a valid positive integer"
                exit 1
            fi
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: qtools set-announce-multiaddrs --public-ip <ip_address> [--workers <int>] [--dry-run]"
            exit 1
            ;;
    esac
done

# Validate public IP is provided
if [ -z "$PUBLIC_IP" ]; then
    echo "Error: --public-ip is required"
    echo "Usage: qtools set-announce-multiaddrs --public-ip <ip_address> [--workers <int>] [--dry-run]"
    exit 1
fi

# Validate IP format
if ! [[ "$PUBLIC_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo "Error: Invalid IP address format: $PUBLIC_IP"
    exit 1
fi

# Check if QUIL config file exists
if [ ! -f "$QUIL_CONFIG_FILE" ]; then
    echo "Error: QUIL config file not found at $QUIL_CONFIG_FILE"
    exit 1
fi

# Read master listen multiaddr
MASTER_LISTEN_MULTIADDR=$(yq eval '.p2p.listenMultiaddr // ""' "$QUIL_CONFIG_FILE")
if [ -z "$MASTER_LISTEN_MULTIADDR" ] || [ "$MASTER_LISTEN_MULTIADDR" = "null" ]; then
    echo "Error: p2p.listenMultiaddr not found in QUIL config"
    exit 1
fi

# Extract port and protocol from master listen multiaddr
# Format: /ip4/0.0.0.0/udp/8336/quic-v1 or /ip4/0.0.0.0/tcp/8336
MASTER_PROTOCOL=$(echo "$MASTER_LISTEN_MULTIADDR" | sed -n 's#.*/ip4/[0-9.]\+/\([a-z]\+\)/.*#\1#p')
MASTER_PORT=$(echo "$MASTER_LISTEN_MULTIADDR" | sed -n 's#.*/\(udp\|tcp\)/\([0-9]\+\).*#\2#p')
MASTER_SUFFIX=""
if echo "$MASTER_LISTEN_MULTIADDR" | grep -q "/quic-v1"; then
    MASTER_SUFFIX="/quic-v1"
fi

if [ -z "$MASTER_PROTOCOL" ] || [ -z "$MASTER_PORT" ]; then
    echo "Error: Could not parse master listen multiaddr: $MASTER_LISTEN_MULTIADDR"
    exit 1
fi

# Read master stream listen multiaddr
MASTER_STREAM_MULTIADDR=$(yq eval '.p2p.streamListenMultiaddr // ""' "$QUIL_CONFIG_FILE")
if [ -z "$MASTER_STREAM_MULTIADDR" ] || [ "$MASTER_STREAM_MULTIADDR" = "null" ]; then
    # Use default port 8340 if not defined
    MASTER_STREAM_PORT=8340
    echo "p2p.streamListenMultiaddr not found in QUIL config, using default port: $MASTER_STREAM_PORT"
else
    # Extract port from master stream listen multiaddr
    # Format: /ip4/0.0.0.0/tcp/8340
    MASTER_STREAM_PORT=$(echo "$MASTER_STREAM_MULTIADDR" | sed -n 's#.*/tcp/\([0-9]\+\).*#\1#p')
    if [ -z "$MASTER_STREAM_PORT" ]; then
        echo "Warning: Could not parse master stream listen multiaddr: $MASTER_STREAM_MULTIADDR, using default port: 8340"
        MASTER_STREAM_PORT=8340
    fi
fi

# Get worker count - use override if provided, otherwise read from config
if [ -n "$WORKER_COUNT_OVERRIDE" ]; then
    WORKER_COUNT="$WORKER_COUNT_OVERRIDE"
else
    # Get worker count from dataWorkerP2PMultiaddrs length
    WORKER_COUNT=$(yq eval '.engine.dataWorkerP2PMultiaddrs | length' "$QUIL_CONFIG_FILE" 2>/dev/null)
    if [ -z "$WORKER_COUNT" ] || [ "$WORKER_COUNT" = "null" ] || [ "$WORKER_COUNT" = "0" ]; then
        WORKER_COUNT=0
    fi
fi

# Get base ports for workers
BASE_P2P_PORT=$(yq eval '.engine.dataWorkerBaseP2PPort // ""' "$QUIL_CONFIG_FILE")
if [ -z "$BASE_P2P_PORT" ] || [ "$BASE_P2P_PORT" = "0" ] || [ "$BASE_P2P_PORT" = "null" ]; then
    BASE_P2P_PORT=$(yq eval '.service.clustering.worker_base_p2p_port // "50000"' "$QTOOLS_CONFIG_FILE")
fi
if [ -z "$BASE_P2P_PORT" ] || [ "$BASE_P2P_PORT" = "0" ]; then
    BASE_P2P_PORT=50000
fi

BASE_STREAM_PORT=$(yq eval '.engine.dataWorkerBaseStreamPort // ""' "$QUIL_CONFIG_FILE")
if [ -z "$BASE_STREAM_PORT" ] || [ "$BASE_STREAM_PORT" = "0" ] || [ "$BASE_STREAM_PORT" = "null" ]; then
    BASE_STREAM_PORT=$(yq eval '.service.clustering.worker_base_stream_port // "60000"' "$QTOOLS_CONFIG_FILE")
fi
if [ -z "$BASE_STREAM_PORT" ] || [ "$BASE_STREAM_PORT" = "0" ]; then
    BASE_STREAM_PORT=60000
fi

# Construct master announce multiaddrs
MASTER_ANNOUNCE_P2P="/ip4/${PUBLIC_IP}/${MASTER_PROTOCOL}/${MASTER_PORT}${MASTER_SUFFIX}"
MASTER_ANNOUNCE_STREAM="/ip4/${PUBLIC_IP}/tcp/${MASTER_STREAM_PORT}"

echo "Master P2P announce multiaddr: $MASTER_ANNOUNCE_P2P"
echo "Master stream announce multiaddr: $MASTER_ANNOUNCE_STREAM"
echo "Worker count: $WORKER_COUNT"
echo "Worker base P2P port: $BASE_P2P_PORT"
echo "Worker base stream port: $BASE_STREAM_PORT"

# Update QUIL config
if [ "$DRY_RUN" == "true" ]; then
    echo "[DRY RUN] Would set:"
    echo "  p2p.announceListenMultiaddr = \"$MASTER_ANNOUNCE_P2P\""
    echo "  p2p.announceStreamListenMultiaddr = \"$MASTER_ANNOUNCE_STREAM\""
    echo "  engine.dataWorkerAnnounceP2PMultiaddrs = []"
    echo "  engine.dataWorkerAnnounceStreamMultiaddrs = []"

    if [ "$WORKER_COUNT" -gt 0 ]; then
        echo "  Would populate worker arrays with $WORKER_COUNT entries:"
        for ((i=0; i<$WORKER_COUNT; i++)); do
            WORKER_P2P_PORT=$((BASE_P2P_PORT + i))
            WORKER_STREAM_PORT=$((BASE_STREAM_PORT + i))
            echo "    dataWorkerAnnounceP2PMultiaddrs[$i] = \"/ip4/${PUBLIC_IP}/tcp/${WORKER_P2P_PORT}\""
            echo "    dataWorkerAnnounceStreamMultiaddrs[$i] = \"/ip4/${PUBLIC_IP}/tcp/${WORKER_STREAM_PORT}\""
        done
    fi
else
    # Set master announce multiaddrs
    yq eval -i ".p2p.announceListenMultiaddr = \"$MASTER_ANNOUNCE_P2P\"" "$QUIL_CONFIG_FILE"
    yq eval -i ".p2p.announceStreamListenMultiaddr = \"$MASTER_ANNOUNCE_STREAM\"" "$QUIL_CONFIG_FILE"

    # Clear and populate worker announce arrays
    yq eval -i '.engine.dataWorkerAnnounceP2PMultiaddrs = []' "$QUIL_CONFIG_FILE"
    yq eval -i '.engine.dataWorkerAnnounceStreamMultiaddrs = []' "$QUIL_CONFIG_FILE"

    if [ "$WORKER_COUNT" -gt 0 ]; then
        echo "Populating worker announce arrays with $WORKER_COUNT entries..."
        for ((i=0; i<$WORKER_COUNT; i++)); do
            WORKER_P2P_PORT=$((BASE_P2P_PORT + i))
            WORKER_STREAM_PORT=$((BASE_STREAM_PORT + i))
            WORKER_P2P_MULTIADDR="/ip4/${PUBLIC_IP}/tcp/${WORKER_P2P_PORT}"
            WORKER_STREAM_MULTIADDR="/ip4/${PUBLIC_IP}/tcp/${WORKER_STREAM_PORT}"

            yq eval -i ".engine.dataWorkerAnnounceP2PMultiaddrs += [\"$WORKER_P2P_MULTIADDR\"]" "$QUIL_CONFIG_FILE"
            yq eval -i ".engine.dataWorkerAnnounceStreamMultiaddrs += [\"$WORKER_STREAM_MULTIADDR\"]" "$QUIL_CONFIG_FILE"
        done
    fi

    echo "Announce multiaddrs updated successfully."
    echo "Restarting service to apply changes..."
    qtools restart
fi

