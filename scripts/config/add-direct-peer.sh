#!/bin/bash
# HELP: Add a direct peer to the node's config file

DRY_RUN="false"
WAIT="false"
PORT=""
PROTOCOL="tcp"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --wait)
            WAIT=true
            shift
            ;;
        --port)
            if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
                PORT="$2"
                shift 2
            else
                echo "Error: --port requires a valid port number"
                exit 1
            fi
            ;;
        --protocol)
            if [[ -n "$2" && "$2" =~ ^(udp|tcp)$ ]]; then
                PROTOCOL="$2"
                shift 2
            else
                echo "Error: --protocol must be either 'udp' or 'tcp'"
                exit 1
            fi
            ;;
        --ip)
            if [[ -n "$2" ]]; then
                PEER_IP="$2"
                shift 2
            else
                echo "Error: --ip requires an IP address"
                exit 1
            fi
            ;;
        --peer-id)
            if [[ -n "$2" ]]; then
                PEER_ID="$2"
                shift 2
            else
                echo "Error: --peer-id requires a peer ID"
                exit 1
            fi
            ;;
        *)
            # Support legacy format: single argument as full multiaddr
            if [ -z "$PEER_IP" ] && [ -z "$PEER_ID" ]; then
                PEER_ADDRESS="$1"
                # Extract peer ID from the address (everything after the last /p2p/)
                PEER_ID=$(echo "$PEER_ADDRESS" | grep -o '/p2p/[^/]*$' | sed 's/\/p2p\///')
                if [ -z "$PEER_ID" ]; then
                    echo "Error: Invalid peer address format. Must include /p2p/ followed by peer ID"
                    echo "Usage: qtools add-direct-peer --ip <ip_address> --peer-id <peer_id> [--port <port>] [--protocol tcp|udp] [--dry-run] [--wait]"
                    echo "   or: qtools add-direct-peer <peer_address>"
                    exit 1
                fi
                # Use the full address as-is
                MULTIADDR="$PEER_ADDRESS"
                shift
            else
                echo "Unknown option: $1"
                echo "Usage: qtools add-direct-peer --ip <ip_address> --peer-id <peer_id> [--port <port>] [--protocol tcp|udp] [--dry-run] [--wait]"
                echo "   or: qtools add-direct-peer <peer_address>"
                exit 1
            fi
            ;;
    esac
done

# If we have IP and peer ID, construct multiaddr
if [ -n "$PEER_IP" ] && [ -n "$PEER_ID" ]; then
    # Validate IP format
    if ! [[ "$PEER_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "Error: Invalid IP address format: $PEER_IP"
        exit 1
    fi

    # Validate peer ID format (should start with Qm or 12D3KooW)
    if ! [[ "$PEER_ID" =~ ^(Qm|12D3KooW) ]]; then
        echo "Warning: Peer ID format may be invalid. Expected to start with 'Qm' or '12D3KooW', got: $PEER_ID"
    fi

    # Get default port from config if not provided
    if [ -z "$PORT" ]; then
        PORT=$(yq eval '.settings.listenAddr.port // 8336' $QTOOLS_CONFIG_FILE)
    fi

    # Validate port range
    if [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
        echo "Error: Port must be between 1 and 65535"
        exit 1
    fi

    # Set protocol suffix based on protocol
    PROTOCOL_SUFFIX=""
    if [ "$PROTOCOL" = "udp" ]; then
        PROTOCOL_SUFFIX="/quic-v1"
    fi

    # Construct multiaddr
    MULTIADDR="/ip4/${PEER_IP}/${PROTOCOL}/${PORT}${PROTOCOL_SUFFIX}/p2p/${PEER_ID}"
elif [ -z "$MULTIADDR" ]; then
    echo "Error: Both --ip and --peer-id are required, or provide a full peer address"
    echo "Usage: qtools add-direct-peer --ip <ip_address> --peer-id <peer_id> [--port <port>] [--protocol tcp|udp] [--dry-run] [--wait]"
    echo "   or: qtools add-direct-peer <peer_address>"
    echo "Example: qtools add-direct-peer --ip 1.2.3.4 --peer-id 12D3KooWxxxxxx --port 8336 --protocol tcp"
    exit 1
fi

# Get local peer ID for validation
LOCAL_PEER_ID=$(qtools --describe "add-direct-peer" peer-id)

# Extract IP from multiaddr if it exists
PEER_IP_FROM_ADDR=$(echo "$MULTIADDR" | grep -oE '/ip4/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | cut -d'/' -f3)
if [ ! -z "$PEER_IP_FROM_ADDR" ]; then
    # Check if IP belongs to local machine
    if ip addr | grep -q "$PEER_IP_FROM_ADDR"; then
        echo "Error: IP $PEER_IP_FROM_ADDR belongs to local machine. Cannot add as direct peer."
        exit 1
    fi
fi

# Extract peer ID from multiaddr if not already set
if [ -z "$PEER_ID" ]; then
    PEER_ID=$(echo "$MULTIADDR" | grep -oE '/p2p/[^/]*' | cut -d'/' -f3)
fi

# Check if peer ID matches local peer ID
if [ "$PEER_ID" == "$LOCAL_PEER_ID" ]; then
    echo "Error: Peer ID $PEER_ID matches local peer ID. Cannot add as direct peer."
    exit 1
fi

# Check if peer already exists in config
EXISTING_PEERS=$(yq eval '.p2p.directPeers[]' $QUIL_CONFIG_FILE 2>/dev/null)
if echo "$EXISTING_PEERS" | grep -q "$PEER_ID"; then
    echo "Warning: A peer with ID $PEER_ID already exists in the config."
    if [ "$DRY_RUN" == "false" ]; then
        echo "Removing existing entry with same peer ID..."
        yq eval "del(.p2p.directPeers[] | select(contains(\"$PEER_ID\")))" -i "$QUIL_CONFIG_FILE"
    fi
fi

# Check if exact multiaddr already exists
if echo "$EXISTING_PEERS" | grep -qF "$MULTIADDR"; then
    echo "Peer with multiaddr $MULTIADDR already exists in config. No changes needed."
    exit 0
fi

# Add the peer
if [ "$DRY_RUN" == "true" ]; then
    echo "[DRY RUN] Would add direct peer: $MULTIADDR"
else
    echo "Adding direct peer: $MULTIADDR"
    yq eval ".p2p.directPeers += [\"$MULTIADDR\"]" -i "$QUIL_CONFIG_FILE"

    if [ "$WAIT" == "true" ]; then
        echo -e "${BLUE}${INFO_ICON} Waiting for next proof submission or workers to be available...${RESET}"
        while read -r line; do
            if [[ $line =~ "submitting data proof" ]] || [[ $line =~ "workers not yet available for proving" ]]; then
                echo -e "${GREEN}${CHECK_ICON} Proof submission detected or workers not available, proceeding with restart${RESET}"
                break
            fi
        done < <(journalctl -u $QUIL_SERVICE_NAME -f -n 0)
    fi

    echo "Direct peer added successfully. Restarting service..."
    qtools --describe "add-direct-peer" restart
fi
