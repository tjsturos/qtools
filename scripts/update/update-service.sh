#!/bin/bash
# HELP: Updates the node\'s service for any changes in the qtools config file.

log "Updating the service..."

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
        --skip-sig-check)
            SKIP_SIGNATURE_CHECK=true
            
            shift
            ;;
        --ipfs-debug)
            IPFS_DEBUGGING=true
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
    yq -i '.service.signature_check = false' $QTOOLS_CONFIG_FILE
else
    yq -i '.service.signature_check = true' $QTOOLS_CONFIG_FILE
fi

if [ "$TESTNET" == "true" ]; then
    yq -i '.service.testnet = true' $QTOOLS_CONFIG_FILE
else
    yq -i '.service.testnet = false' $QTOOLS_CONFIG_FILE
fi

if [ "$DEBUG_MODE" == "true" ]; then
    yq -i '.service.debug = true' $QTOOLS_CONFIG_FILE
else
    yq -i '.service.debug = false' $QTOOLS_CONFIG_FILE
fi

# Define the initial service file content as a variable
SERVICE_CONTENT="[Unit]
Description=Quilibrium Ceremony Client Service

[Service]
Type=simple
Restart=always
RestartSec=$(yq '.service.restart_time' $QTOOLS_CONFIG_FILE)
User=$(whoami)
WorkingDirectory=$QUIL_NODE_PATH
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
WorkingDirectory=$QUIL_NODE_PATH
Restart=on-failure
RestartSec=5s
StartLimitBurst=5
User=$USER
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
echo "Clustering: $IS_CLUSTERING_ENABLED, IS MASTER: $IS_MASTER"
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
