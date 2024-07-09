#!/bin/bash
# HELP: Updates the node\'s service for any changes in the qtools config file.

log "Updating the service..."

update_or_add_line() {
    local KEY=$1
    local VALUE=$2
    sudo sed -i -e "/^$KEY=/c\\$KEY=$VALUE" "$QUIL_SERVICE_FILE"
    if ! grep -q "^$KEY=" "$QUIL_SERVICE_FILE"; then
        sudo sed -i "/\[Service\]/a $KEY=$VALUE" "$QUIL_SERVICE_FILE"
    fi
}

get_processor_count() {
  # Get the CPU count using the nproc command
  cpu_count=$(nproc)

  # Print the CPU count
  echo $cpu_count
}

update_service_binary() {
    local QUIL_BIN="$(get_versioned_node)"
    # local INLINE_ARGS="$(yq '.service.args' $QTOOLS_CONFIG_FILE)"
    local NEW_EXECSTART="$QUIL_NODE_PATH/$QUIL_BIN \$NODE_ARGS"
    local WORKING_DIR="$(yq '.service.working_dir' $QTOOLS_CONFIG_FILE)"
    local RESTART_SEC="$(yq '.service.restart_time' $QTOOLS_CONFIG_FILE)"
    local CURRENT_USER=$(whoami)
    local CURRENT_GROUP=$(id -gn)

    update_or_add_line "ExecStart" "$NEW_EXECSTART"
    update_or_add_line "WorkingDirectory" "$WORKING_DIR"
    update_or_add_line "RestartSec" "$RESTART_SEC"
    update_or_add_line "User" "$CURRENT_USER"
    update_or_add_line "Group" "$CURRENT_GROUP"

    sudo chmod +x $QUIL_NODE_PATH/$QUIL_BIN
    sudo systemctl daemon-reload

    log "Service: ExecStart=$NEW_EXECSTART"
    log "Service: WorkingDirectory=$WORKING_DIR"
    log "Service: RestartSec=$RESTART_SEC"
    log "Service: User=$CURRENT_USER"
    log "Service: Group=$CURRENT_GROUP"
}

updateCPUQuota() {
    local CPULIMIT=$(yq '.settings.cpulimit.enabled' "$QTOOLS_CONFIG_FILE")

    if $CPULIMIT == 'true'; then
        # we only want to set CPU limits on bare-metal
        if ! lscpu | grep -q "Hypervisor vendor:     KVM"; then
            # Calculate the CPUQuota value
            local CPU_LIMIT_PERCENT=$(yq ".settings.cpulimit.limit_percentage" "$QTOOLS_CONFIG_FILE")
            local CPU_QUOTA=$(echo "$CPU_LIMIT_PERCENT * $(get_processor_count)" | bc)%
            
            # Check if the service file contains the [Service] section
            if grep -q "^\[Service\]" "$QUIL_SERVICE_FILE"; then
                # Check if CPUQuota is already present in the [Service] section
                if grep -q "^CPUQuota=" "$QUIL_SERVICE_FILE"; then
                    # Get the current CPUQuota value
                    CURRENT_CPUQUOTA=$(grep "^CPUQuota=" "$QUIL_SERVICE_FILE" | cut -d'=' -f2)
                    # Update the existing CPUQuota line only if the value is different
                    if [ "$CURRENT_CPUQUOTA" != "$CPU_QUOTA" ]; then
                        sudo sed -i "s/^CPUQuota=.*/CPUQuota=$CPU_QUOTA/" "$QUIL_SERVICE_FILE"
                        sudo systemctl daemon-reload
                        log "Systemctl CPUQuota updated to $CPU_QUOTA in $QUIL_SERVICE_FILE"
                    fi
                else
                    # Append CPUQuota to the [Service] section
                    sudo sed -i "/^\[Service\]/a CPUQuota=$CPU_QUOTA" "$QUIL_SERVICE_FILE"
                    sudo systemctl daemon-reload
                    log "Systemctl CPUQuota updated to $CPU_QUOTA in $QUIL_SERVICE_FILE"
                fi
            else
                # If [Service] section does not exist, add it and append CPUQuota
                sudo -- sh -c "echo -e \"[Service]\nCPUQuota=$CPU_QUOTA\" >> \"$QUIL_SERVICE_FILE\""
                sudo systemctl daemon-reload
                log "Systemctl CPUQuota updated to $CPU_QUOTA in $QUIL_SERVICE_FILE"
            fi   
        fi
    else
        sudo sed -i "/^CPUQuota=/d" "$QUIL_SERVICE_FILE"
        log "CPUQuota not enabled."
    fi
}

createServiceIfNone() {
    local SERVICE_FILENAME="$1@.service"
    if [ ! -f "$SYSTEMD_SERVICE_PATH/$SERVICE_FILENAME" ]; then
        log "No service found at $SYSTEMD_SERVICE_PATH/$SERVICE_FILENAME.  Creating service file..."
        sudo cp $QTOOLS_PATH/$SERVICE_FILENAME $SYSTEMD_SERVICE_PATH
    fi
}

# update normal service
createServiceIfNone $QUIL_SERVICE_NAME
updateCPUQuota 
update_service_binary
