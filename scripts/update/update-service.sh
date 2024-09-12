#!/bin/bash
# HELP: Updates the node's service for any changes in the qtools config file.

log "Updating the service..."

get_processor_count() {
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
RestartSec=5s
User=ubuntu
Group=ubuntu
WorkingDirectory=/home/ubuntu/ceremonyclient/node
Environment="GOMAXPROCS=$(get_processor_count)"
ExecStart=node-$(get_current_version)-linux-amd64

[Install]
WantedBy=multi-user.target"

update_or_add_line() {
    local KEY=$1
    local VALUE=$2
    SERVICE_CONTENT=$(echo "$SERVICE_CONTENT" | sed -e "/^$KEY=/c\\$KEY=$VALUE")
    if ! echo "$SERVICE_CONTENT" | grep -q "^$KEY="; then
        SERVICE_CONTENT=$(echo "$SERVICE_CONTENT" | sed "/\[Service\]/a $KEY=$VALUE")
    fi
}


update_service_binary() {
    local QUIL_BIN="$(get_versioned_node)"
    local NEW_EXECSTART="$QUIL_NODE_PATH/$QUIL_BIN"
    local WORKING_DIR="$(yq '.service.working_dir' $QTOOLS_CONFIG_FILE)"
    local RESTART_SEC="$(yq '.service.restart_time' $QTOOLS_CONFIG_FILE)"
    local CURRENT_USER=$(whoami)
    local CURRENT_GROUP=$(id -gn)
    local GOMAXPROCS=$(yq '.service.max_workers // false' $QTOOLS_CONFIG_FILE)

    update_or_add_line "ExecStart" "$NEW_EXECSTART"
    update_or_add_line "WorkingDirectory" "$WORKING_DIR"
    update_or_add_line "RestartSec" "$RESTART_SEC"
    update_or_add_line "User" "$CURRENT_USER"
    update_or_add_line "Group" "$CURRENT_GROUP"

    if [ "$GOMAXPROCS" != "false" ] && [ "$GOMAXPROCS" != "0" ] && [ "$GOMAXPROCS" -eq "$GOMAXPROCS" ] 2>/dev/null; then
        update_or_add_line "Environment" "GOMAXPROCS=$GOMAXPROCS"
        log "Service: Environment=GOMAXPROCS=$GOMAXPROCS"
    fi

    sudo chmod +x $QUIL_NODE_PATH/$QUIL_BIN

    log "Service: ExecStart=$NEW_EXECSTART"
    log "Service: WorkingDirectory=$WORKING_DIR"
    log "Service: RestartSec=$RESTART_SEC"
    log "Service: User=$CURRENT_USER"
    log "Service: Group=$CURRENT_GROUP"
}

updateCPUQuota() {
    local CPULIMIT=$(yq '.settings.cpulimit.enabled' "$QTOOLS_CONFIG_FILE")

    if [ "$CPULIMIT" = "true" ]; then
        # we only want to set CPU limits on bare-metal
        if ! lscpu | grep -q "Hypervisor vendor:     KVM"; then
            # Calculate the CPUQuota value
            local CPU_LIMIT_PERCENT=$(yq ".settings.cpulimit.limit_percentage" "$QTOOLS_CONFIG_FILE")
            local CPU_QUOTA=$(echo "$CPU_LIMIT_PERCENT * $(get_processor_count)" | bc)%
            
            update_or_add_line "CPUQuota" "$CPU_QUOTA"
            log "Systemctl CPUQuota updated to $CPU_QUOTA"
        fi
    else
        SERVICE_CONTENT=$(echo "$SERVICE_CONTENT" | sed "/^CPUQuota=/d")
        log "CPUQuota not enabled."
    fi
}

createServiceIfNone() {
    local SERVICE_FILENAME="$1.service"
    if [ ! -f "$SYSTEMD_SERVICE_PATH/$SERVICE_FILENAME" ]; then
        log "No service found at $SYSTEMD_SERVICE_PATH/$SERVICE_FILENAME. Creating service file..."
        echo "$SERVICE_CONTENT" | sudo tee "$SYSTEMD_SERVICE_PATH/$SERVICE_FILENAME" > /dev/null
    else
        echo "$SERVICE_CONTENT" | sudo tee "$SYSTEMD_SERVICE_PATH/$SERVICE_FILENAME" > /dev/null
    fi
}

# update normal service
createServiceIfNone $QUIL_SERVICE_NAME
updateCPUQuota 
update_service_binary

# Apply changes
sudo systemctl daemon-reload
