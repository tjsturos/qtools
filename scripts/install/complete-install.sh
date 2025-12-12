#/bin/bash
# HELP: Runs a complete install of the node.
# USAGE: qtools complete-install [--peer-id <peer_id>] [--listen-port <port>] [--stream-port <port>] [--base-p2p-port <port>] [--base-stream-port <port>]
#
# Options:
#   --peer-id <peer_id>         Specify a custom peer ID for the node. If not provided,
#                               a new peer ID will be generated automatically.
#   --listen-port <port>        Set the main P2P listen port (default: 8336).
#                               This is the port for .p2p.listenMultiaddr
#   --stream-port <port>        Set the stream listen port (default: 8340).
#                               This is the port for .p2p.streamListenMultiaddr
#   --base-p2p-port <port>      Set the base P2P port for workers (default: 50000).
#                               Worker P2P ports will start from this value.
#   --base-stream-port <port>   Set the base stream port for workers (default: 60000).
#                               Worker stream ports will start from this value.
#
# This script performs a complete installation of the Quilibrium node.
# If a peer ID is provided, it will be used for the node configuration and backups.
# Otherwise, a new peer ID will be generated during the installation process.


sudo apt-get -q update

# Parse command line arguments
PEER_ID=""
RESTORE=false
LISTEN_PORT=""
STREAM_PORT=""
BASE_P2P_PORT=""
BASE_STREAM_PORT=""
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --peer-id)
        PEER_ID="$2"
        shift # past argument
        shift # past value
        ;;
        --restore)
        RESTORE=true
        shift # past argument
        ;;
        --listen-port)
        LISTEN_PORT="$2"
        shift # past argument
        shift # past value
        ;;
        --stream-port)
        STREAM_PORT="$2"
        shift # past argument
        shift # past value
        ;;
        --base-p2p-port)
        BASE_P2P_PORT="$2"
        shift # past argument
        shift # past value
        ;;
        --base-stream-port)
        BASE_STREAM_PORT="$2"
        shift # past argument
        shift # past value
        ;;
        *)    # unknown option
        shift # past argument
        ;;
    esac
done


DISABLE_SSH_PASSWORDS="$(yq '.settings.install.ssh.disable_password_login // "false"' $QTOOLS_CONFIG_FILE)"

# Helper function to safely modify QUIL_CONFIG_FILE that might be owned by quilibrium user
# This handles the case where the user was just added to the quilibrium group
# but the current shell session doesn't have the group membership active yet
safe_modify_quil_config() {
    local yq_command="$1"
    if [ -f "$QUIL_CONFIG_FILE" ]; then
        local file_owner=$(stat -c '%U' "$QUIL_CONFIG_FILE" 2>/dev/null || stat -f '%Su' "$QUIL_CONFIG_FILE" 2>/dev/null || echo "")
        if [ "$file_owner" == "quilibrium" ] && [ "$(whoami)" != "root" ]; then
            sudo yq eval -i "$yq_command" "$QUIL_CONFIG_FILE"
        else
            yq eval -i "$yq_command" "$QUIL_CONFIG_FILE"
        fi
    fi
}

cd $QUIL_HOME

# Create quilibrium user for running node services
qtools create-quilibrium-user

qtools download-node --link
qtools download-qclient --link
qtools update-service

qtools install-go
qtools install-grpc
qtools setup-firewall
qtools install-cron
qtools expand-storage

generate_default_config() {
    # This first command generates a default config file
    BINARY_NAME="$(get_current_versioned_node)"
    BINARY_FILE=$QUIL_NODE_PATH/$BINARY_NAME

    # Check if QUIL_NODE_PATH is owned by quilibrium user
    # If so, use sg to activate quilibrium group for this command
    # This handles the case where user was just added to quilibrium group
    # but current shell session doesn't have group membership active yet
    local node_path_owner=$(stat -c '%U' "$QUIL_NODE_PATH" 2>/dev/null || stat -f '%Su' "$QUIL_NODE_PATH" 2>/dev/null || echo "")
    if [ "$node_path_owner" == "quilibrium" ] && [ "$(whoami)" != "root" ]; then
        # Use sg to run with quilibrium group active
        sg quilibrium -c "$BINARY_FILE -peer-id" 2>/dev/null || sudo $BINARY_FILE -peer-id
    else
        $BINARY_FILE -peer-id
    fi
    sleep 3
    if [ -f $BINARY_FILE ]; then
        qtools modify-config
    fi
}

if [ "$PEER_ID" != "" ]; then
    log "Attempting to restore from remote backup. Note: backups must be enabled and configured properly (and connected to at least once) for this to work."

    if [ "$PEER_ID" != "false" ] && [ "$PEER_ID" != "" ]; then
        qtools restore-backup --peer-id $PEER_ID --force
        wait
        if [ -f $BINARY_FILE ]; then
            qtools modify-config
        fi
    else
        log "No peer ID found, skipping restore."
        generate_default_config
    fi
else
    generate_default_config
fi

# Set main listen port if provided
if [ "$LISTEN_PORT" != "" ]; then
    # Validate port number
    if ! [[ "$LISTEN_PORT" =~ ^[0-9]+$ ]] || [ "$LISTEN_PORT" -lt 1 ] || [ "$LISTEN_PORT" -gt 65535 ]; then
        log "Error: --listen-port must be a valid port number between 1 and 65535"
        exit 1
    fi
    log "Setting listen port to $LISTEN_PORT"
    # Update qtools config
    qtools config set-value settings.listenAddr.port "$LISTEN_PORT" --quiet
    # Update quil config - get listen mode from config
    if [ -f "$QUIL_CONFIG_FILE" ]; then
        LISTEN_MODE=$(yq eval '.settings.listenAddr.mode // "udp"' $QTOOLS_CONFIG_FILE)
        if [ "$LISTEN_MODE" = "udp" ]; then
            PROTOCOL="/quic-v1"
        else
            PROTOCOL=""
        fi
        safe_modify_quil_config ".p2p.listenMultiaddr = \"/ip4/0.0.0.0/${LISTEN_MODE}/${LISTEN_PORT}${PROTOCOL}\""
    fi
fi

# Set stream listen port if provided
if [ "$STREAM_PORT" != "" ]; then
    # Validate port number
    if ! [[ "$STREAM_PORT" =~ ^[0-9]+$ ]] || [ "$STREAM_PORT" -lt 1 ] || [ "$STREAM_PORT" -gt 65535 ]; then
        log "Error: --stream-port must be a valid port number between 1 and 65535"
        exit 1
    fi
    log "Setting stream listen port to $STREAM_PORT"
    # Update qtools config
    qtools config set-value service.clustering.master_stream_port "$STREAM_PORT" --quiet
    # Update quil config
    if [ -f "$QUIL_CONFIG_FILE" ]; then
        safe_modify_quil_config ".p2p.streamListenMultiaddr = \"/ip4/0.0.0.0/tcp/${STREAM_PORT}\""
    fi
fi

# Set base ports if provided
if [ "$BASE_P2P_PORT" != "" ]; then
    # Validate port number
    if ! [[ "$BASE_P2P_PORT" =~ ^[0-9]+$ ]] || [ "$BASE_P2P_PORT" -lt 1 ] || [ "$BASE_P2P_PORT" -gt 65535 ]; then
        log "Error: --base-p2p-port must be a valid port number between 1 and 65535"
        exit 1
    fi
    log "Setting base P2P port to $BASE_P2P_PORT"
    yq eval -i ".service.clustering.worker_base_p2p_port = $BASE_P2P_PORT" $QTOOLS_CONFIG_FILE
    if [ -f "$QUIL_CONFIG_FILE" ]; then
        safe_modify_quil_config ".engine.dataWorkerBaseP2PPort = $BASE_P2P_PORT"
    fi
fi

if [ "$BASE_STREAM_PORT" != "" ]; then
    # Validate port number
    if ! [[ "$BASE_STREAM_PORT" =~ ^[0-9]+$ ]] || [ "$BASE_STREAM_PORT" -lt 1 ] || [ "$BASE_STREAM_PORT" -gt 65535 ]; then
        log "Error: --base-stream-port must be a valid port number between 1 and 65535"
        exit 1
    fi
    log "Setting base stream port to $BASE_STREAM_PORT"
    qtools config set-value service.clustering.worker_base_stream_port "$BASE_STREAM_PORT" --quiet
    if [ -f "$QUIL_CONFIG_FILE" ]; then
        safe_modify_quil_config ".engine.dataWorkerBaseStreamPort = $BASE_STREAM_PORT"
    fi
fi

# tells server to always start node service on reboot
qtools enable

if [ "$DISABLE_SSH_PASSWORDS" == 'true' ]; then

    PUBLIC_KEY_URL="$(yq '.settings.install.ssh.public_key_url' $QTOOLS_CONFIG_FILE)"
    PUBLIC_KEY="$(yq '.settings.install.ssh.public_key_string' $QTOOLS_CONFIG_FILE)"

    # if defined, fetch remote public key
    if [ ! -z "$PUBLIC_KEY_URL" ]; then
        PUBLIC_KEY="$(dig TXT $PUBLIC_KEY_URL +short | sed -e 's/" "//g' -e 's/"//g')"
    fi

    if [ ! -z "$PUBLIC_KEY" ]; then
        qtools add-public-ssh-key "$PUBLIC_KEY"
    fi

    # Check if authorized_keys file exists and is not empty
    if [ ! -s "$HOME/.ssh/authorized_keys" ]; then
        log "No authorized keys found. Skipping SSH password disable for safety."
        exit 0
    fi

    qtools disable-ssh-passwords
fi

source $QTOOLS_PATH/scripts/install/customization.sh

