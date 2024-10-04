is_master() {
    MAIN_IP=$(yq '.service.clustering.main_ip' $QTOOLS_CONFIG_FILE)
    if echo "$(hostname -I)" | grep -q "$MAIN_IP"; then
        echo "true"
    else
        echo "false"
    fi
}

create_dataworker_service_file() {
    local BINARY=$(get_versioned_node)
    local service_file="/etc/systemd/system/$QUIL_SERVICE_NAME-dataworker@.service"
    if [ "$DRY_RUN" == "true" ]; then
        echo -e "${BLUE}${INFO_ICON} [DRY RUN] Would create $service_file if it doesn't exist${RESET}"
    else
        USER=$(whoami)
        GROUP=$(id -gn)
        if [ -z "$USER" ] || [ -z "$GROUP" ]; then
            echo "Error: Failed to get user or group information"
            exit 1
        fi
        echo -e "${BLUE}${INFO_ICON} Creating $QUIL_SERVICE_NAME-dataworker@.service file...${RESET}"
        sudo tee "$service_file" > /dev/null <<EOF
[Unit]
Description=Quilibrium Dataworker Service

[Service]
Type=simple
Restart=always
RestartSec=50ms
User=$USER
Group=$GROUP
WorkingDirectory=$(yq '.service.working_dir // "'$QUIL_NODE_PATH'"' $QTOOLS_CONFIG_FILE)
ExecStart=$QUIL_NODE_PATH/$BINARY --core %i


[Install]
WantedBy=multi-user.target
EOF
        sudo systemctl daemon-reload
        echo -e "${BLUE}${INFO_ICON} Service file created and systemd reloaded.${RESET}"
    fi
}

start_control_process() {
    echo -e "${BLUE}${INFO_ICON} Starting $QUIL_SERVICE_NAME.service${RESET}"
    sudo systemctl enable $QUIL_SERVICE_NAME.service
    sudo systemctl start $QUIL_SERVICE_NAME.service
}

# Function to start a single core
start_core() {
    local CORE=$1
    if [ "$DRY_RUN" == "true" ]; then
        echo -e "${BLUE}${INFO_ICON} [DRY RUN] Would enable and start $QUIL_SERVICE_NAME-dataworker@$CORE.service${RESET}"
    else
        if ! sudo systemctl start $QUIL_SERVICE_NAME-dataworker@$CORE.service; then
            echo -e "\e[31mFailed to start $QUIL_SERVICE_NAME-dataworker@$CORE.service.\e[0m"
        else
            echo -e "\e[32mStarted $QUIL_SERVICE_NAME-dataworker@$CORE.service\e[0m"
            sudo systemctl enable $QUIL_SERVICE_NAME-dataworker@$CORE.service
        fi
    fi
}


start_local_cores() {
    local CORE_INDEX_START=$1
    local CORE_COUNT=$2
    echo -e "${BLUE}${INFO_ICON} Starting cluster's dataworkers on local machine${RESET}"
    for ((i=0; i<CORE_COUNT; i++)); do
        CORE=$((INDEX_START + i))
        start_core $CORE &
    done
}

start_remote_cores() {
    local IP=$1
    local CORE_INDEX_START=$2  
    local CORE_COUNT=$3
    echo -e "${BLUE}${INFO_ICON} Starting cluster's dataworkers on $IP${RESET}"
    ssh -i ~/.ssh/cluster-key "$IP" "qtools start-cluster \
        --index-start $CORE_INDEX_START \
        --data-worker-count $CORE_COUNT"
}

get_cluster_server_info() {
    local servers=$(yq eval '.service.clustering.servers' $QTOOLS_CONFIG_FILE)
    local server_count=$(echo "$servers" | yq eval '. | length' -)
    local current_ip=false
    local current_dataworker_count=0
    local current_index_start=0

    for ((i=0; i<$server_count; i++)); do
        local server=$(yq eval ".service.clustering.servers[$i]" $QTOOLS_CONFIG_FILE)
        local ip=$(echo "$server" | yq eval '.ip' -)
        local dataworker_count=$(echo "$server" | yq eval '.dataworker_count' -)
        local index_start=$(echo "$server" | yq eval '.index_start' -)

        if echo "$(hostname -I)" | grep -q "$ip"; then
            current_ip=$ip
            current_dataworker_count=$dataworker_count
            current_index_start=$index_start
        fi
    done
    echo "$current_ip $current_dataworker_count $current_index_start"
}

update_quil_config() {
    local DRY_RUN=${1:-false}
    config=$(yq eval . $QTOOLS_CONFIG_FILE)
    
    # Get the array of servers
    servers=$(echo "$config" | yq eval '.service.clustering.servers' -)

    # Clear the existing dataworkerMultiaddrs array
    yq eval -i '.engine.dataWorkerMultiaddrs = []' "$QUIL_CONFIG_FILE"

    # Initialize TOTAL_EXPECTED_DATAWORKERS
    TOTAL_EXPECTED_DATAWORKERS=0

    # Get the number of servers
    server_count=$(echo "$servers" | yq eval '. | length' -)

    SERVER_CORE_INDEX_START=0
    SERVER_CORE_INDEX_END=0
    # Loop through each server
    for ((i=0; i<server_count; i++)); do
        server=$(echo "$servers" | yq eval ".[$i]" -)
        ip=$(echo "$server" | yq eval '.ip' -)
        dataworker_count=$(echo "$server" | yq eval '.dataworker_count // "false"' -)
        
        # Skip invalid entries
        if [ -z "$ip" ] || [ "$ip" == "null" ]; then
            echo "Skipping invalid server entry: $server"
            continue
        fi

        echo "Processing server: $ip"
        echo "Server: $ip, Dataworker count: $dataworker_count"
        
        if echo "$(hostname -I)" | grep -q "$ip"; then
            yq eval -i ".service.clustering.main_ip = \"$ip\"" $QTOOLS_CONFIG_FILE
            echo "Set main IP to $ip in clustering configuration"
            # This is the master server, so subtract 1 from the total core count
            available_cores=$(($(nproc) - 1))
            if [ "$dataworker_count" == "false" ]; then
                dataworker_count=$(($(nproc) - 1))
            fi

            # Convert dataworker_count to integer and ensure it's not greater than available cores
            dataworker_count=$(echo "$dataworker_count" | tr -cd '0-9')
            dataworker_count=$((dataworker_count > 0 ? dataworker_count : available_cores))
            dataworker_count=$((dataworker_count < available_cores ? dataworker_count : available_cores))
        else
            # Get the number of available cores
            available_cores=$(ssh -i ~/.ssh/cluster-key "$ip" nproc)
            
            # Convert dataworker_count to integer and ensure it's not greater than available cores
            dataworker_count=$(echo "$dataworker_count" | tr -cd '0-9')
            dataworker_count=$((dataworker_count > 0 ? dataworker_count : available_cores))
            dataworker_count=$((dataworker_count < available_cores ? dataworker_count : available_cores))
        fi

        echo "Dataworker count for $ip: $dataworker_count"
        
        # Increment the global count
        TOTAL_EXPECTED_DATAWORKERS=$((TOTAL_EXPECTED_DATAWORKERS + dataworker_count))

        for ((j=0; j<dataworker_count; j++)); do
            port=$((40000 + j + SERVER_CORE_INDEX_START))
            if [ "$DRY_RUN" == "false" ]; then
                yq eval -i ".engine.dataWorkerMultiaddrs += \"/ip4/$ip/tcp/$port\"" "$QUIL_CONFIG_FILE"
            else
                echo "Dry run, skipping adding dataworker multiaddr: /ip4/$ip/tcp/$port"
            fi
            SERVER_CORE_INDEX_END=$((SERVER_CORE_INDEX_END + 1))
        done
        

        SERVER_CORE_INDEX_START=$((SERVER_CORE_INDEX_END))
    done

    # Print out the number of dataworker multiaddrs
    actual_dataworkers=$(yq eval '.engine.dataWorkerMultiaddrs | length' "$QUIL_CONFIG_FILE")

    if [ "$TOTAL_EXPECTED_DATAWORKERS" -ne "$actual_dataworkers" ]; then
        echo -e "\e[33mWarning: The number of dataworker multiaddrs in the config doesn't match the expected count.\e[0m"
        echo -e "${BLUE}${INFO_ICON} Dataworkers to be started: $TOTAL_EXPECTED_DATAWORKERS${RESET}"
        echo -e "${BLUE}${INFO_ICON} Actual dataworker multiaddrs in config: $actual_dataworkers${RESET}"
    else
        echo -e "${BLUE}${INFO_ICON} Number of actual dataworkers found ($actual_dataworkers) matches the expected amount.${RESET}"
    fi
}

copy_quil_config_to_server() {
    local ip=$1

    scp -i ~/.ssh/cluster-key "$QUIL_CONFIG_FILE" "$ip:$HOME/ceremonyclient/node/.config/config.yml"
}

copy_qtools_config_to_server() {
    local ip=$1

    scp -i ~/.ssh/cluster-key "$QTOOLS_CONFIG_FILE" "$ip:$HOME/qtools/config.yml"
}

