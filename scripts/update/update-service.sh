#!/bin/bash
# HELP: Updates the node\'s service for any changes in the qtools config file.

log "Updating the service..."

getProcessorCount() {
  # Get the CPU count using the nproc command
  cpu_count=$(nproc)

  # Print the CPU count
  echo $cpu_count
}

IS_CORE_SERVICE=false
IS_CLUSTER_MODE=$(yq '.service.clustering.enabled // false' $QTOOLS_CONFIG_FILE)
CORE_NUMBER=""
SERVICE_FILE=$QUIL_SERVICE_FILE
SERVICE_NAME=$QUIL_SERVICE_NAME
ENABLE_SERVICE=false
RESTART_SERVICE=false
TESTNET=false

if [ "$IS_CLUSTER_MODE" == "true" ] && [ "$(is_master)" == "false" ]; then
    if [ "$(is_master)" == "true" ]; then
        qtools stop
        qtools setup-cluster --master
        qtools start
    fi
    # do not update normally on clustered nodes
    exit 0
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --testnet)
            TESTNET=true
            shift
            ;;
        --core)
            if [ "$IS_CLUSTER_MODE" == "true" ]; then
                if [[ "$2" =~ ^[0-9]+$ ]]; then
                    IS_CORE_SERVICE=true
                    CORE_NUMBER="$2"
                    SERVICE_FILE="${QUIL_SERVICE_FILE%.*}-$CORE_NUMBER.service"
                    SERVICE_NAME="${QUIL_SERVICE_NAME%.*}-$CORE_NUMBER.service"
                else
                    echo "Error: --core requires a numeric argument"
                    exit 1
                fi
            else
                echo "Error: --core is only available in cluster mode"
                exit 1
            fi
            shift 2
            ;;
        --enable)
            ENABLE_SERVICE=true
            shift
            ;;
        --restart)
            RESTART_SERVICE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done



# Define the initial service file content as a variable
SERVICE_CONTENT="[Unit]
Description=Quilibrium Ceremony Client Service

[Service]
Type=simple
Restart=always
RestartSec=$(yq '.service.restart_time' $QTOOLS_CONFIG_FILE)
User=$(whoami)
WorkingDirectory=$QUIL_NODE_PATH
Environment="GOMAXPROCS=$(getProcessorCount)"
ExecStart=${LINKED_NODE_BINARY}${TESTNET:+ --network 1}
ExecStop=/bin/kill -s SIGINT \$MAINPID
ExecReload=/bin/kill -s SIGINT \$MAINPID && ${LINKED_NODE_BINARY}${TESTNET:+ --network 1}
KillSignal=SIGINT
RestartKillSignal=SIGINT
FinalKillSignal=SIGINT
KillSignal=SIGINT
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target"


updateOrAddLine() {
    local KEY=$1
    local VALUE=$2
    SERVICE_CONTENT=$(echo "$SERVICE_CONTENT" | sed -e "/^$KEY=/c\\$KEY=$VALUE")
    if ! echo "$SERVICE_CONTENT" | grep -q "^$KEY="; then
        SERVICE_CONTENT=$(echo "$SERVICE_CONTENT" | sed "/\[Service\]/a $KEY=$VALUE")
    fi
}

updateServiceBinary() {
    # Check if --core parameter is passed
    if [ "$IS_CORE_SERVICE" != "true" ]; then
        local goMaxProcs=$(yq '.service.max_threads // false' $QTOOLS_CONFIG_FILE)

        if [ "$goMaxProcs" != "false" ] && [ "$goMaxProcs" != "0" ] && [ "$goMaxProcs" -eq "$goMaxProcs" ] 2>/dev/null; then
            updateOrAddLine "Environment" "GOMAXPROCS=$goMaxProcs"
            log "Service: Environment=GOMAXPROCS=$goMaxProcs"
        else
            log "Not updating GOMAXPROCS: $goMaxProcs"
        fi
    fi

    sudo chmod +x $QUIL_NODE_PATH/$QUIL_BIN

    echo "$SERVICE_CONTENT" | sudo tee "$SERVICE_FILE" > /dev/null
    sudo systemctl daemon-reload
}

updateCPUQuota() {
    local CPULIMIT=$(yq '.settings.cpulimit.enabled' "$QTOOLS_CONFIG_FILE")

    if [ "$CPULIMIT" == "true" ]; then
        # we only want to set CPU limits on bare-metal
        if ! lscpu | grep -q "Hypervisor vendor:     KVM"; then
            # Calculate the CPUQuota value
            local CPU_LIMIT_PERCENT=$(yq ".settings.cpulimit.limit_percentage" "$QTOOLS_CONFIG_FILE")
            local CPU_QUOTA=$(echo "$CPU_LIMIT_PERCENT * $(getProcessorCount)" | bc)%
            
            updateOrAddLine "CPUQuota" "$CPU_QUOTA"
            log "Systemctl CPUQuota updated to $CPU_QUOTA"
        fi
    else
        SERVICE_CONTENT=$(echo "$SERVICE_CONTENT" | sed "/^CPUQuota=/d")
        log "CPUQuota not enabled."
    fi
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
createServiceIfNone 
updateCPUQuota 
updateServiceBinary

if [ "$IS_CORE_SERVICE" == "true" ]; then
    log "Core service created."
fi

if [ "$ENABLE_SERVICE" == "true" ]; then
    log "Enabling service..."
    sudo systemctl enable "$SERVICE_NAME"
fi

if [ "$RESTART_SERVICE" == "true" ]; then
    log "Restarting service..."
    sudo systemctl restart "$SERVICE_NAME"
fi

