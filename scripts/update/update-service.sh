#!/bin/bash

log "Updating the service..."

update_service_binary() {
    local QUIL_BIN="$(get_versioned_node)"
    local INLINE_ARGS="$(yq '.service.args // \"\"' $QTOOLS_CONFIG_FILE)"
    local NEW_EXECSTART="ExecStart=$QUIL_NODE_PATH/$QUIL_BIN \$NODE_ARGS $INLINE_ARGS"
    local WORKING_DIR="WorkingDirectory=$(yq '.service.working_dir' $QTOOLS_CONFIG_FILE)"
    local RESTART_SEC="RestartSec=$(yq '.service.restart_time // \"5s\"' $QTOOLS_CONFIG_FILE)"
    sudo sed -i -e "/^ExecStart=/c\\$NEW_EXECSTART" "$QUIL_SERVICE_FILE"
    sudo sed -i -e "/^WorkingDirectory=/c\\$WORKING_DIR" "$QUIL_SERVICE_FILE"
    sudo sed -i -e "/^RestartSec=/c\\$RESTART_SEC" "$QUIL_SERVICE_FILE"
    # Update the service file if needed
    sudo chmod +x $QUIL_NODE_PATH/$QUIL_BIN
    sudo systemctl daemon-reload

    log "Service: $NEW_EXECSTART"
    log "Service: $WORKING_DIR"
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
                        sed -i "s/^CPUQuota=.*/CPUQuota=$CPU_QUOTA/" "$QUIL_SERVICE_FILE"
                        sudo systemctl daemon-reload
                        log "Systemctl CPUQuota updated to $CPU_QUOTA in $QUIL_SERVICE_FILE"
                    fi
                else
                    # Append CPUQuota to the [Service] section
                    sed -i "/^\[Service\]/a CPUQuota=$CPU_QUOTA" "$QUIL_SERVICE_FILE"
                    sudo systemctl daemon-reload
                    log "Systemctl CPUQuota updated to $CPU_QUOTA in $QUIL_SERVICE_FILE"
                fi
            else
                # If [Service] section does not exist, add it and append CPUQuota
                echo -e "[Service]\nCPUQuota=$CPU_QUOTA" >> "$QUIL_SERVICE_FILE"
                sudo systemctl daemon-reload
                log "Systemctl CPUQuota updated to $CPU_QUOTA in $QUIL_SERVICE_FILE"
            fi   
        fi
    fi
}

createServiceIfNone() {
    local SERVICE_FILENAME="$1@.service"
    if [ ! -f "$SYSTEMD_SERVICE_PATH/$SERVICE_FILENAME" ]; then
        log "No service found at $SYSTEMD_SERVICE_PATH/$SERVICE_FILENAME.  Creating service file..."
        cp $QTOOLS_PATH/$SERVICE_FILENAME $SYSTEMD_SERVICE_PATH
    fi
}

# update normal service
createServiceIfNone $QUIL_SERVICE_NAME
updateCPUQuota 
update_service_binary
