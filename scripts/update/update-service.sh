#!/bin/bash

log "Updating the service..."

update_service_binary() {
    local NEW_EXECSTART="$1"
    local QUIL_BIN="$2"
    sudo sed -i -e "/^ExecStart=/c\\$NEW_EXECSTART" "$QUIL_SERVICE_FILE"
    # Update the service file if needed
    sudo systemctl daemon-reload

    log "Systemctl binary version updated to $QUIL_BIN"
}

updateCPUQuota() {
    local SERVICE_FILE="$1"
    local CPULIMIT=$(yq e '.settings.cpulimit.enabled' "$QTOOLS_CONFIG_FILE")

    if $CPULIMIT == 'true'; then
        # we only want to set CPU limits on bare-metal
        if ! lscpu | grep -q "Hypervisor vendor:     KVM"; then
            # Calculate the CPUQuota value
            local CPU_LIMIT_PERCENT=$(yq e ".settings.cpulimit.limit_percentage" "$QTOOLS_CONFIG_FILE")
            local CPU_QUOTA=$(echo "$CPU_LIMIT_PERCENT * $(get_processor_count)" | bc)%
            
            
            # Check if the service file contains the [Service] section
            if grep -q "^\[Service\]" "$SERVICE_FILE"; then
                # Check if CPUQuota is already present in the [Service] section
                if grep -q "^CPUQuota=" "$SERVICE_FILE"; then
                    # Get the current CPUQuota value
                    CURRENT_CPUQUOTA=$(grep "^CPUQuota=" "$SERVICE_FILE" | cut -d'=' -f2)
                    # Update the existing CPUQuota line only if the value is different
                    if [ "$CURRENT_CPUQUOTA" != "$CPU_QUOTA" ]; then
                        sed -i "s/^CPUQuota=.*/CPUQuota=$CPU_QUOTA/" "$SERVICE_FILE"
                        sudo systemctl daemon-reload
                        log "Systemctl CPUQuota updated to $CPU_QUOTA in $SERVICE_FILE"
                    fi
                else
                    # Append CPUQuota to the [Service] section
                    sed -i "/^\[Service\]/a CPUQuota=$CPU_QUOTA" "$SERVICE_FILE"
                    sudo systemctl daemon-reload
                    log "Systemctl CPUQuota updated to $CPU_QUOTA in $SERVICE_FILE"
                fi
            else
                # If [Service] section does not exist, add it and append CPUQuota
                echo -e "[Service]\nCPUQuota=$CPU_QUOTA" >> "$SERVICE_FILE"
                sudo systemctl daemon-reload
                log "Systemctl CPUQuota updated to $CPU_QUOTA in $SERVICE_FILE"
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

QUIL_BIN="node-$available_version-$(get_os_arch)"

# update normal service
NEW_EXECSTART="ExecStart=$QUIL_NODE_PATH/$QUIL_BIN \$NODE_ARGS" 
createServiceIfNone $QUIL_SERVICE_NAME
updateCPUQuota $QUIL_SERVICE_FILE
update_service_binary $QUIL_SERVICE_FILE "$NEW_EXECSTART" "$QUIL_BIN"
