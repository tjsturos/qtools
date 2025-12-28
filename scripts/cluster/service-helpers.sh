#!/bin/bash
# Unified service helper functions for automatic, local cluster, and full cluster modes

# Source utils if not already sourced
if [ -z "$LOCAL_IP" ]; then
    source $QTOOLS_PATH/scripts/cluster/utils.sh
fi

# Mode detection functions
is_clustering_enabled() {
    yq eval '.service.clustering.enabled // false' $QTOOLS_CONFIG_FILE
}

is_manual_mode() {
    yq eval '.manual.enabled // false' $QTOOLS_CONFIG_FILE
}

is_local_only() {
    local enabled=$(is_clustering_enabled)
    if [ "$enabled" == "true" ]; then
        yq eval '.service.clustering.local_only // false' $QTOOLS_CONFIG_FILE
    else
        echo "false"
    fi
}

should_use_worker_services() {
    # Workers are services if clustering is enabled (local or full) or manual mode is enabled
    if [ "$(is_manual_mode)" == "true" ]; then
        echo "true"
    else
        is_clustering_enabled
    fi
}

# Get worker count based on mode
get_worker_count() {
    if [ "$(is_manual_mode)" == "true" ]; then
        local count=$(yq eval '.manual.worker_count // "0"' $QTOOLS_CONFIG_FILE)
        if [ "$count" == "false" ] || [ -z "$count" ] || [ "$count" == "0" ]; then
            echo "0"
        else
            echo "$count"
        fi
    elif [ "$(is_clustering_enabled)" == "true" ]; then
        local count=$(yq eval '.service.clustering.local_data_worker_count // "false"' $QTOOLS_CONFIG_FILE)
        if [ "$count" == "false" ] || [ -z "$count" ]; then
            if [ "$(is_master)" == "true" ]; then
                echo $(($(nproc) - 1))
            else
                echo $(nproc)
            fi
        else
            echo "$count"
        fi
    else
        echo "0"  # Automatic mode - master spawns workers
    fi
}

# Note: calculate_server_core_index() and get_server_info_for_core_index() are defined in utils.sh

# Start master service
start_master_service() {
    if [ "$(is_clustering_enabled)" == "true" ] && [ "$(is_master)" == "false" ]; then
        # Not master node in cluster mode, skip
        return 0
    fi

    if systemctl is-active $QUIL_SERVICE_NAME >/dev/null 2>&1; then
        echo -e "${BLUE}${INFO_ICON} Master service is already running${RESET}"
        return 0
    fi

    echo -e "${BLUE}${INFO_ICON} Starting master service...${RESET}"
    sudo systemctl start $QUIL_SERVICE_NAME.service
}

# Stop master service
stop_master_service() {
    if [ "$(is_clustering_enabled)" == "true" ] && [ "$(is_master)" == "false" ]; then
        # Not master node in cluster mode, skip
        return 0
    fi

    if ! systemctl is-active $QUIL_SERVICE_NAME >/dev/null 2>&1; then
        echo -e "${BLUE}${INFO_ICON} Master service is not running${RESET}"
        return 0
    fi

    echo -e "${BLUE}${INFO_ICON} Stopping master service...${RESET}"
    sudo systemctl stop $QUIL_SERVICE_NAME.service
}

# Start all workers
start_workers() {
    if [ "$(should_use_worker_services)" != "true" ]; then
        # Automatic mode - master spawns workers, no-op
        return 0
    fi

    local worker_count=$(get_worker_count)
    if [ "$worker_count" -le 0 ]; then
        echo -e "${BLUE}${INFO_ICON} No workers configured${RESET}"
        return 0
    fi

    # Manual mode uses core indices starting from 1
    if [ "$(is_manual_mode)" == "true" ]; then
        echo -e "${BLUE}${INFO_ICON} Starting manual mode workers from core 1 to $worker_count${RESET}"
        for ((i=1; i<=$worker_count; i++)); do
            start_manual_worker $i
        done
    else
        local base_index=$(get_base_index_for_server "$LOCAL_IP")
        local start_index=$base_index
        local end_index=$((start_index + worker_count - 1))

        echo -e "${BLUE}${INFO_ICON} Starting workers from core $start_index to $end_index${RESET}"
        start_local_data_worker_services $start_index $end_index $LOCAL_IP
    fi
}

# Stop all workers
stop_workers() {
    if [ "$(should_use_worker_services)" != "true" ]; then
        # Automatic mode - master handles workers, no-op
        return 0
    fi

    # Manual mode uses core indices starting from 1
    if [ "$(is_manual_mode)" == "true" ]; then
        local worker_count=$(get_worker_count)
        if [ "$worker_count" -gt 0 ]; then
            echo -e "${BLUE}${INFO_ICON} Stopping manual mode workers from core 1 to $worker_count${RESET}"
            for ((i=1; i<=$worker_count; i++)); do
                stop_manual_worker $i
            done
        fi
    else
        echo -e "${BLUE}${INFO_ICON} Stopping all worker services...${RESET}"
        stop_local_data_worker_services
    fi
}

# Start a specific worker by core index
start_worker_by_core_index() {
    local core_index="$1"

    if [ -z "$core_index" ]; then
        echo -e "${RED}${ERROR_ICON} Core index is required${RESET}"
        return 1
    fi

    # Manual mode handling
    if [ "$(is_manual_mode)" == "true" ]; then
        start_manual_worker "$core_index"
        return $?
    fi

    # Get server info for this core index
    local server_info=$(get_server_info_for_core_index "$core_index")
    if [ -z "$server_info" ]; then
        echo -e "${RED}${ERROR_ICON} Core index $core_index not found in cluster configuration${RESET}"
        return 1
    fi

    IFS='|' read -r server_ip remote_user ssh_port local_core <<< "$server_info"

    # Check if this is local or remote
    if echo "$(hostname -I)" | grep -q "$server_ip" || echo "$server_ip" | grep -q "127.0.0.1"; then
        # Local server
        if [ "$(should_use_worker_services)" == "true" ]; then
            echo -e "${BLUE}${INFO_ICON} Starting worker service for core $core_index (local core $local_core)${RESET}"
            sudo systemctl start ${QUIL_DATA_WORKER_SERVICE_NAME}@${core_index}.service
        else
            echo -e "${BLUE}${INFO_ICON} Automatic mode: worker $core_index is managed by master process${RESET}"
        fi
    else
        # Remote server - SSH to start
        if [ "$(is_clustering_enabled)" == "true" ]; then
            echo -e "${BLUE}${INFO_ICON} Starting worker service for core $core_index on $server_ip (local core $local_core)${RESET}"
            ssh_to_remote "$server_ip" "$remote_user" "$ssh_port" "sudo systemctl start ${QUIL_DATA_WORKER_SERVICE_NAME}@${core_index}.service"
        else
            echo -e "${RED}${ERROR_ICON} Cannot start remote worker in automatic mode${RESET}"
            return 1
        fi
    fi
}

# Stop a specific worker by core index
stop_worker_by_core_index() {
    local core_index="$1"

    if [ -z "$core_index" ]; then
        echo -e "${RED}${ERROR_ICON} Core index is required${RESET}"
        return 1
    fi

    # Manual mode handling
    if [ "$(is_manual_mode)" == "true" ]; then
        stop_manual_worker "$core_index"
        return $?
    fi

    # Get server info for this core index
    local server_info=$(get_server_info_for_core_index "$core_index")
    if [ -z "$server_info" ]; then
        echo -e "${RED}${ERROR_ICON} Core index $core_index not found in cluster configuration${RESET}"
        return 1
    fi

    IFS='|' read -r server_ip remote_user ssh_port local_core <<< "$server_info"

    # Check if this is local or remote
    if echo "$(hostname -I)" | grep -q "$server_ip" || echo "$server_ip" | grep -q "127.0.0.1"; then
        # Local server
        if [ "$(should_use_worker_services)" == "true" ]; then
            echo -e "${BLUE}${INFO_ICON} Stopping worker service for core $core_index (local core $local_core)${RESET}"
            sudo systemctl stop ${QUIL_DATA_WORKER_SERVICE_NAME}@${core_index}.service
        else
            # In automatic mode, need to kill the process
            local binary_name=$(basename "$LINKED_NODE_BINARY")
            local pid=$(pgrep -f "${binary_name}.*--core ${core_index}" | head -n 1)
            if [ -n "$pid" ]; then
                echo -e "${BLUE}${INFO_ICON} Stopping worker process for core $core_index (PID: $pid)${RESET}"
                sudo kill -SIGINT "$pid"
            else
                echo -e "${YELLOW}${WARNING_ICON} Worker process for core $core_index not found${RESET}"
            fi
        fi
    else
        # Remote server - SSH to stop
        if [ "$(is_clustering_enabled)" == "true" ]; then
            echo -e "${BLUE}${INFO_ICON} Stopping worker service for core $core_index on $server_ip (local core $local_core)${RESET}"
            ssh_to_remote "$server_ip" "$remote_user" "$ssh_port" "sudo systemctl stop ${QUIL_DATA_WORKER_SERVICE_NAME}@${core_index}.service"
        else
            echo -e "${RED}${ERROR_ICON} Cannot stop remote worker in automatic mode${RESET}"
            return 1
        fi
    fi
}

# Start a manual mode worker by core index
start_manual_worker() {
    local core_index="$1"

    if [ -z "$core_index" ]; then
        echo -e "${RED}${ERROR_ICON} Core index is required${RESET}"
        return 1
    fi

    if [ "$core_index" == "0" ]; then
        echo -e "${RED}${ERROR_ICON} Core index 0 is reserved for master process${RESET}"
        return 1
    fi

    # Get worker service name
    QUIL_DATA_WORKER_SERVICE_NAME=$(yq '.service.clustering.data_worker_service_name // "dataworker"' $QTOOLS_CONFIG_FILE)

    echo -e "${BLUE}${INFO_ICON} Starting manual worker service for core $core_index${RESET}"
    sudo systemctl start ${QUIL_DATA_WORKER_SERVICE_NAME}@${core_index}.service
}

# Stop a manual mode worker by core index
stop_manual_worker() {
    local core_index="$1"

    if [ -z "$core_index" ]; then
        echo -e "${RED}${ERROR_ICON} Core index is required${RESET}"
        return 1
    fi

    if [ "$core_index" == "0" ]; then
        echo -e "${RED}${ERROR_ICON} Core index 0 is reserved for master process${RESET}"
        return 1
    fi

    # Get worker service name
    QUIL_DATA_WORKER_SERVICE_NAME=$(yq '.service.clustering.data_worker_service_name // "dataworker"' $QTOOLS_CONFIG_FILE)

    echo -e "${BLUE}${INFO_ICON} Stopping manual worker service for core $core_index${RESET}"
    sudo systemctl stop ${QUIL_DATA_WORKER_SERVICE_NAME}@${core_index}.service
}
