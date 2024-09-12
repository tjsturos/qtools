#!/bin/bash
# HELP: Updates the node's service for any changes in the qtools config file.

log "Updating the service..."

getProcessorCount() {
  # Get the CPU count using the nproc command
  cpu_count=$(nproc)

  # Print the CPU count
  echo $cpu_count
}

# Define the initial service file content as a variable
SERVICE_CONTENT="[Unit]
Description=Quilibrium Ceremony Client Service

[Service]
Type=simple
Restart=always
RestartSec=$(yq '.service.restart_time' $QTOOLS_CONFIG_FILE)
User=$(whoami)
Group=$(id -gn)
WorkingDirectory=$(yq '.service.working_dir' $QTOOLS_CONFIG_FILE)
Environment="GOMAXPROCS=$(getProcessorCount)"
ExecStart=$QUIL_NODE_PATH/$(get_versioned_node)

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
    local goMaxProcs=$(yq '.service.max_workers // false' $QTOOLS_CONFIG_FILE)

    if [ "$goMaxProcs" != "false" ] && [ "$goMaxProcs" != "0" ] && [ "$goMaxProcs" -eq "$goMaxProcs" ] 2>/dev/null; then
        updateOrAddLine "Environment" "GOMAXPROCS=$goMaxProcs"
        log "Service: Environment=GOMAXPROCS=$goMaxProcs"
    else
        log "Not updating GOMAXPROCS: $goMaxProcs"
    fi

    sudo chmod +x $QUIL_NODE_PATH/$QUIL_BIN

    echo "$SERVICE_CONTENT" | sudo tee "$QUIL_SERVICE_FILE" > /dev/null
    sudo systemctl daemon-reload
}

updateCPUQuota() {
    local CPULIMIT=$(yq '.settings.cpulimit.enabled' "$QTOOLS_CONFIG_FILE")

    if [ "$CPULIMIT" = "true" ]; then
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
    if [ ! -f "$QUIL_SERVICE_FILE" ]; then
        log "No service found at $QUIL_SERVICE_FILE. Creating service file..."
        echo "$SERVICE_CONTENT" | sudo tee "$QUIL_SERVICE_FILE" > /dev/null
    else
        echo "$SERVICE_CONTENT" | sudo tee "$QUIL_SERVICE_FILE" > /dev/null
    fi
}

# update normal service
createServiceIfNone 
updateCPUQuota 
updateServiceBinary


