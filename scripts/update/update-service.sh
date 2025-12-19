#!/bin/bash
# HELP: Updates the node\'s service for any changes in the qtools config file.

log "Updating the service..."

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

getProcessorCount() {
  # Get the CPU count using the nproc command
  cpu_count=$(nproc)

  # Print the CPU count
  echo $cpu_count
}

SERVICE_FILE=$QUIL_SERVICE_FILE
SERVICE_NAME=$QUIL_SERVICE_NAME
ENABLE_SERVICE=false
RESTART_SERVICE=false
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
            shift
            ;;
        --enable)
            ENABLE_SERVICE=true
            shift
            ;;
        --restart)
            RESTART_SERVICE=true
            shift
            ;;
        --debug)
            DEBUG_MODE=true
            shift
            ;;
        --skip-sig-check|--skip-signature-check)
            SKIP_SIGNATURE_CHECK=true
            shift
            ;;
        --signature-check=*)
            VALUE="${1#*=}"
            if [ "$VALUE" == "false" ]; then
                SKIP_SIGNATURE_CHECK=true
            fi
            shift
            ;;
        --ipfs-debug)
            IPFS_DEBUGGING=true
            shift
            ;;
        --restart-time)
            SERVICE_RESTART_TIME=$2
            shift
            shift
            ;;
        --gogc)
            GOGC=$2
            shift
            shift
            ;;
        --gomemlimit)
            GOMEMLIMIT=$2
            shift
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ "$SKIP_SIGNATURE_CHECK" == "true" ]; then
    qtools config set-value service.signature_check "false" --quiet
else
    qtools config set-value service.signature_check "true" --quiet
fi

if [ "$TESTNET" == "true" ]; then
    qtools config set-value service.testnet "true" --quiet
else
    qtools config set-value service.testnet "false" --quiet
fi

if [ "$DEBUG_MODE" == "true" ]; then
    qtools config set-value service.debug "true" --quiet
else
    qtools config set-value service.debug "false" --quiet
fi

if [ -n "$SERVICE_RESTART_TIME" ]; then
    # Allow integer (e.g. 20) or integer+s (e.g. 20s), normalize to "<int>s"
    if [[ "$SERVICE_RESTART_TIME" =~ ^[0-9]+$ ]]; then
        SERVICE_RESTART_TIME="${SERVICE_RESTART_TIME}s"
    elif ! [[ "$SERVICE_RESTART_TIME" =~ ^[0-9]+s$ ]]; then
        echo "Error: Service restart time must be a positive integer or a positive integer followed by 's'"
        exit 1
    fi
    qtools config set-value service.restart_time "$SERVICE_RESTART_TIME" --quiet
else
    # Read from config file, default to 60s if not found or invalid
    SERVICE_RESTART_TIME="$(qtools config get-value service.restart_time --default "60s")"
    # Validate the value from config file
    if [[ "$SERVICE_RESTART_TIME" =~ ^[0-9]+$ ]]; then
        SERVICE_RESTART_TIME="${SERVICE_RESTART_TIME}s"
    elif ! [[ "$SERVICE_RESTART_TIME" =~ ^[0-9]+s$ ]]; then
        # Invalid value in config, default to 60s
        SERVICE_RESTART_TIME="60s"
        qtools config set-value service.restart_time "60s" --quiet
    fi
fi

# Define the initial service file content as a variable
SERVICE_CONTENT="[Unit]
Description=Quilibrium Ceremony Client Service

[Service]
Type=simple
Restart=always
RestartSec=$SERVICE_RESTART_TIME
User=$SERVICE_USER
Group=$QTOOLS_GROUP
WorkingDirectory=$QUIL_NODE_PATH_FOR_SERVICE
Environment="${IPFS_DEBUGGING:+ IPFS_LOGGING=debug}"
ExecStart=${LINKED_NODE_BINARY}${TESTNET:+ --network=1}${DEBUG_MODE:+ --debug}${SKIP_SIGNATURE_CHECK:+ --signature-check=false}
ExecStop=/bin/kill -s SIGINT \$MAINPID
ExecReload=/bin/kill -s SIGINT \$MAINPID && ${LINKED_NODE_BINARY}${TESTNET:+ --network=1}${DEBUG_MODE:+ --debug}${SKIP_SIGNATURE_CHECK:+ --signature-check=false}
KillSignal=SIGINT
RestartKillSignal=SIGINT
FinalKillSignal=SIGKILL
KillSignal=SIGINT
TimeoutStopSec=240

[Install]
WantedBy=multi-user.target"

DATA_WORKER_SERVICE_CONTENT="[Unit]
Description=Quilibrium Worker Service %i
After=network.target
Wants=network-online.target
StartLimitIntervalSec=0

[Service]
Type=simple
WorkingDirectory=$QUIL_NODE_PATH_FOR_SERVICE
Restart=on-failure
RestartSec=5s
StartLimitBurst=5
User=$SERVICE_USER
Group=$QTOOLS_GROUP
${GOGC:+Environment=GOGC=${GOGC}}
${GOMEMLIMIT:+Environment=GOMEMLIMIT=${GOMEMLIMIT}}
ExecStart=${LINKED_NODE_BINARY}${TESTNET:+ --network=1}${DEBUG_MODE:+ --debug}${SKIP_SIGNATURE_CHECK:+ --signature-check=false} --core %i
ExecStop=/bin/kill -s SIGINT \$MAINPID
ExecReload=/bin/kill -s SIGINT \$MAINPID && ${LINKED_NODE_BINARY}${TESTNET:+ --network=1}${DEBUG_MODE:+ --debug}${SKIP_SIGNATURE_CHECK:+ --signature-check=false} --core %i
KillSignal=SIGINT
RestartKillSignal=SIGINT
FinalKillSignal=SIGKILL
TimeoutStopSec=240

CPUSchedulingPolicy=rr
CPUSchedulingPriority=$(yq '.service.dataworker_priority // 90' $QTOOLS_CONFIG_FILE)

[Install]
WantedBy=multi-user.target"

updateServiceContent() {
    local CONTENT=$1
    local FILE=$2
    echo "$CONTENT" | sudo tee "$FILE" > /dev/null
}

updateServiceBinary() {
    updateServiceContent "$SERVICE_CONTENT" "$SERVICE_FILE"
}

updateDataWorkerServiceBinary() {
    updateServiceContent "$DATA_WORKER_SERVICE_CONTENT" "$QUIL_DATA_WORKER_SERVICE_FILE"
}

createServiceIfNone() {
    log "Checking if service file exists at $SERVICE_FILE"
    if [ ! -f "$SERVICE_FILE" ]; then
        log "No service found at $SERVICE_FILE. Creating service file..."
        echo "$SERVICE_CONTENT" | sudo tee "$SERVICE_FILE" > /dev/null
    else
        echo "$SERVICE_CONTENT" | sudo tee "$SERVICE_FILE" > /dev/null
    fi
}

# update normal service
if [ "$IS_CLUSTERING_ENABLED" == "true" ]; then
    if [ "$IS_MASTER" == "true" ]; then
        createServiceIfNone
        updateServiceBinary
    elif [ -f $SERVICE_FILE ]; then
        sudo rm $SERVICE_FILE
    fi
else
    createServiceIfNone
    updateServiceBinary
fi

updateDataWorkerServiceBinary
sudo systemctl daemon-reload

if [ "$ENABLE_SERVICE" == "true" ]; then
    log "Enabling service..."
    sudo systemctl enable "$SERVICE_NAME"
fi

if [ "$RESTART_SERVICE" == "true" ]; then
    log "Restarting service..."
    sudo systemctl restart "$SERVICE_NAME"
fi
