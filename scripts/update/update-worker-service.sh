#!/bin/bash
# HELP: Updates the worker service template for manual mode workers
# NOTE: --testnet must be used with update-service, not directly with this script
# PARAM: --debug: Enable debug mode
# PARAM: --skip-sig-check|--skip-signature-check: Skip signature check
# PARAM: --ipfs-debug: Enable IPFS debugging (for compatibility, doesn't apply to workers)
# PARAM: --restart-time <value>: Set restart time for worker services
# PARAM: --gogc <value>: Set GOGC environment variable
# PARAM: --gomemlimit <value>: Set GOMEMLIMIT environment variable
# Usage: qtools update-worker-service --gogc 100
# Usage: qtools update-worker-service --gomemlimit 8GiB
# Usage: qtools update-worker-service --restart-time 10s
# Usage: qtools update-service --testnet (updates both master and workers with --testnet)

# Source required utilities
source $QTOOLS_PATH/utils/index.sh

log "Updating the worker service..."

# Check if --testnet is being used in a direct call (not from update-service)
# --testnet must always go through update-service to update both master and workers
if [ -z "$QTOOLS_UPDATE_SERVICE_CALLER" ]; then
    # Check if --testnet is in the arguments
    for arg in "$@"; do
        if [ "$arg" == "--testnet" ]; then
            echo "Error: --testnet cannot be used with update-worker-service directly."
            echo "Please use 'qtools update-service --testnet' instead, which will update both master and worker services."
            echo ""
            echo "Examples:"
            echo "  qtools update-service --testnet          # Updates both with --testnet"
            echo "  qtools update-service --master --testnet # Updates both with --testnet (--testnet overrides --master)"
            echo ""
            echo "For other options, you can use update-worker-service directly:"
            echo "  qtools update-worker-service --gogc 100"
            echo "  qtools update-worker-service --gomemlimit 8GiB"
            echo "  qtools update-worker-service --restart-time 10s"
            exit 1
        fi
    done
fi

# Get the service user from config, default to 'quilibrium'
SERVICE_USER=$(yq '.service.default_user // "quilibrium"' $QTOOLS_CONFIG_FILE)

# Ensure quilibrium user exists
if [ "$SERVICE_USER" == "quilibrium" ]; then
    if ! id "$SERVICE_USER" &>/dev/null; then
        log "Quilibrium user not found. Creating it..."
        qtools create-quilibrium-user
    fi
    # Use quilibrium user's node path
    QUIL_NODE_PATH_FOR_SERVICE="/home/quilibrium/ceremonyclient/node"
    # Check if quilibrium_node_path is configured
    CONFIGURED_PATH=$(yq '.service.quilibrium_node_path // ""' $QTOOLS_CONFIG_FILE)
    if [ -n "$CONFIGURED_PATH" ] && [ "$CONFIGURED_PATH" != "null" ]; then
        # Replace $HOME with /home/quilibrium for quilibrium user
        CONFIGURED_PATH=$(echo "$CONFIGURED_PATH" | sed "s|\$HOME|/home/quilibrium|g")
        # Expand any remaining variables in the path
        QUIL_NODE_PATH_FOR_SERVICE=$(eval echo "$CONFIGURED_PATH")
    fi
else
    # Use the current QUIL_NODE_PATH for other users
    QUIL_NODE_PATH_FOR_SERVICE="$QUIL_NODE_PATH"
fi

# Parse command line arguments (accept all flags for compatibility, even if not all apply to workers)
TESTNET=""
DEBUG_MODE=""
SKIP_SIGNATURE_CHECK=""
IPFS_DEBUGGING=""
GOGC=""
GOMEMLIMIT=""
SERVICE_RESTART_TIME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --testnet)
            TESTNET=true
            mkdir -p $QUIL_NODE_PATH/test
            qtools config set-value service.testnet "true" --quiet
            shift
            ;;
        --debug)
            DEBUG_MODE=true
            qtools config set-value service.debug "true" --quiet
            shift
            ;;
        --skip-sig-check|--skip-signature-check)
            SKIP_SIGNATURE_CHECK=true
            qtools config set-value service.signature_check "false" --quiet
            shift
            ;;
        --signature-check=*)
            VALUE="${1#*=}"
            if [ "$VALUE" == "false" ]; then
                SKIP_SIGNATURE_CHECK=true
                qtools config set-value service.signature_check "false" --quiet
            fi
            shift
            ;;
        --ipfs-debug)
            IPFS_DEBUGGING=true
            qtools config set-value service.ipfs_debug "true" --quiet
            shift
            ;;
        --restart-time)
            SERVICE_RESTART_TIME=$2
            qtools config set-value service.worker_service.restart_time "$SERVICE_RESTART_TIME" --quiet
            shift
            shift
            ;;
        --gogc)
            GOGC=$2
            qtools config set-value service.worker_service.gogc "$GOGC" --quiet
            shift
            shift
            ;;
        --gomemlimit)
            GOMEMLIMIT=$2
            qtools config set-value service.worker_service.gomemlimit "$GOMEMLIMIT" --quiet
            shift
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Get service settings from config (use command line args if provided, otherwise from config)
if [ -z "$TESTNET" ]; then
    TESTNET=$(yq '.service.testnet // "false"' $QTOOLS_CONFIG_FILE)
fi
if [ -z "$DEBUG_MODE" ]; then
    DEBUG_MODE=$(yq '.service.debug // "false"' $QTOOLS_CONFIG_FILE)
fi
if [ -z "$SKIP_SIGNATURE_CHECK" ]; then
    SIGNATURE_CHECK=$(yq '.service.signature_check // "true"' $QTOOLS_CONFIG_FILE)
    if [ "$SIGNATURE_CHECK" == "false" ]; then
        SKIP_SIGNATURE_CHECK=true
    fi
fi
if [ -z "$GOGC" ]; then
    GOGC=$(yq '.service.worker_service.gogc // ""' $QTOOLS_CONFIG_FILE)
fi
if [ -z "$GOMEMLIMIT" ]; then
    GOMEMLIMIT=$(yq '.service.worker_service.gomemlimit // ""' $QTOOLS_CONFIG_FILE)
fi

# Get IPFS debugging setting from config if not provided
if [ -z "$IPFS_DEBUGGING" ]; then
    IPFS_DEBUG=$(yq '.service.ipfs_debug // "false"' $QTOOLS_CONFIG_FILE)
    if [ "$IPFS_DEBUG" == "true" ]; then
        IPFS_DEBUGGING=true
    fi
fi

# Handle restart-time
if [ -n "$SERVICE_RESTART_TIME" ]; then
    # Allow integer (e.g. 20) or integer+s (e.g. 20s), normalize to "<int>s"
    if [[ "$SERVICE_RESTART_TIME" =~ ^[0-9]+$ ]]; then
        SERVICE_RESTART_TIME="${SERVICE_RESTART_TIME}s"
    elif ! [[ "$SERVICE_RESTART_TIME" =~ ^[0-9]+s$ ]]; then
        echo "Error: Service restart time must be a positive integer or a positive integer followed by 's'"
        exit 1
    fi
else
    # Read from worker_service config first, then fall back to service.restart_time, default to 5s
    SERVICE_RESTART_TIME=$(yq '.service.worker_service.restart_time // ""' $QTOOLS_CONFIG_FILE)
    if [ -z "$SERVICE_RESTART_TIME" ] || [ "$SERVICE_RESTART_TIME" == "null" ]; then
        SERVICE_RESTART_TIME="$(qtools config get-value service.restart_time --default "5s")"
    fi
    # Validate the value from config file
    if [[ "$SERVICE_RESTART_TIME" =~ ^[0-9]+$ ]]; then
        SERVICE_RESTART_TIME="${SERVICE_RESTART_TIME}s"
    elif ! [[ "$SERVICE_RESTART_TIME" =~ ^[0-9]+s$ ]]; then
        # Invalid value in config, default to 5s
        SERVICE_RESTART_TIME="5s"
        qtools config set-value service.worker_service.restart_time "5s" --quiet
    fi
fi

# Build testnet flag
TESTNET_FLAG=""
if [ "$TESTNET" == "true" ]; then
    TESTNET_FLAG=" --network=1"
fi

# Build debug flag
DEBUG_FLAG=""
if [ "$DEBUG_MODE" == "true" ]; then
    DEBUG_FLAG=" --debug"
fi

# Build signature check flag
SIG_CHECK_FLAG=""
if [ "$SKIP_SIGNATURE_CHECK" == "true" ]; then
    SIG_CHECK_FLAG=" --signature-check=false"
fi

# Build environment variables (similar to update-service.sh)
# These will be conditionally included in the service file using ${VAR:+value} syntax

# Build ExecStart and ExecReload commands
EXEC_START="${LINKED_NODE_BINARY}${TESTNET_FLAG}${DEBUG_FLAG}${SIG_CHECK_FLAG} --core %i"
EXEC_RELOAD="/bin/kill -s SIGINT \$MAINPID && ${LINKED_NODE_BINARY}${TESTNET_FLAG}${DEBUG_FLAG}${SIG_CHECK_FLAG} --core %i"

# Define the worker service file content
DATA_WORKER_SERVICE_CONTENT="[Unit]
Description=Quilibrium Worker Service %i
After=network.target
Wants=network-online.target
StartLimitIntervalSec=0

[Service]
Type=simple
WorkingDirectory=$QUIL_NODE_PATH_FOR_SERVICE
Restart=on-failure
RestartSec=$SERVICE_RESTART_TIME
StartLimitBurst=5
User=$SERVICE_USER
Group=$QTOOLS_GROUP
${IPFS_DEBUGGING:+Environment=IPFS_LOGGING=debug}
${GOGC:+Environment=GOGC=${GOGC}}
${GOMEMLIMIT:+Environment=GOMEMLIMIT=${GOMEMLIMIT}}
ExecStart=${EXEC_START}
ExecStop=/bin/kill -s SIGINT \$MAINPID
ExecReload=${EXEC_RELOAD}
KillSignal=SIGINT
RestartKillSignal=SIGINT
FinalKillSignal=SIGKILL
TimeoutStopSec=240

CPUSchedulingPolicy=rr
CPUSchedulingPriority=$(yq '.service.dataworker_priority // 90' $QTOOLS_CONFIG_FILE)

[Install]
WantedBy=multi-user.target"

# Update the worker service file
updateServiceContent() {
    local CONTENT=$1
    local FILE=$2
    echo "$CONTENT" | sudo tee "$FILE" > /dev/null
}

# Get the worker service file path
QUIL_DATA_WORKER_SERVICE_NAME=$(yq '.service.clustering.data_worker_service_name // "dataworker"' $QTOOLS_CONFIG_FILE)
QUIL_DATA_WORKER_SERVICE_FILE="/etc/systemd/system/${QUIL_DATA_WORKER_SERVICE_NAME}@.service"

# Update the worker service file
updateServiceContent "$DATA_WORKER_SERVICE_CONTENT" "$QUIL_DATA_WORKER_SERVICE_FILE"
sudo systemctl daemon-reload

log "Worker service updated successfully"

