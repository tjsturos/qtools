#/bin/bash
# IGNORE

SSH_KEY_PAIR_NAME=$(yq eval '.service.clustering.ssh_key_name' $QTOOLS_CONFIG_FILE)
SSH_KEY_PATH=$(eval echo $(yq eval '.service.clustering.ssh_key_path' $QTOOLS_CONFIG_FILE))
export SSH_CLUSTER_KEY=$SSH_KEY_PATH/$SSH_KEY_PAIR_NAME
export DEFAULT_USER=$(eval echo $(yq eval '.service.clustering.default_user // "ubuntu"' $QTOOLS_CONFIG_FILE))
export DEFAULT_SSH_PORT=$(yq eval '.service.clustering.default_ssh_port // "22"' $QTOOLS_CONFIG_FILE)
export QUIL_DATA_WORKER_SERVICE_NAME="$(yq eval '.service.clustering.data_worker_service_name // "dataworker"' $QTOOLS_CONFIG_FILE)"
export BASE_PORT=$(yq eval '.service.clustering.base_port // "40000"' $QTOOLS_CONFIG_FILE)
export WORKER_BASE_P2P_PORT=$(yq eval '.engine.dataWorkerBaseP2PPort // .service.clustering.worker_base_p2p_port // "50000"' $QUIL_CONFIG_FILE $QTOOLS_CONFIG_FILE)
export WORKER_BASE_STREAM_PORT=$(yq eval '.engine.dataWorkerBaseStreamPort // .service.clustering.worker_base_stream_port // "60000"' $QUIL_CONFIG_FILE $QTOOLS_CONFIG_FILE)
if [ -z "$WORKER_BASE_P2P_PORT" ] || [ "$WORKER_BASE_P2P_PORT" = "0" ]; then WORKER_BASE_P2P_PORT=50000; fi
if [ -z "$WORKER_BASE_STREAM_PORT" ] || [ "$WORKER_BASE_STREAM_PORT" = "0" ]; then WORKER_BASE_STREAM_PORT=60000; fi

MASTER_SERVICE_NAME=$(yq eval '.service.clustering.master_service_name' $QTOOLS_CONFIG_FILE)
MASTER_SERVICE_FILE="/etc/systemd/system/$MASTER_SERVICE_NAME.service"
DATA_WORKER_SERVICE_NAME=$(yq eval '.service.clustering.data_worker_service_name' $QTOOLS_CONFIG_FILE)
DATA_WORKER_SERVICE_FILE="/etc/systemd/system/$DATA_WORKER_SERVICE_NAME@.service"
DATA_WORKER_COUNT=$(yq eval '.service.clustering.local_data_worker_count' $QTOOLS_CONFIG_FILE)


LOCAL_IP=$(get_local_ip)

ssh_to_remote() {
    local IP=$1
    local USER=$2
    local SSH_PORT=$3
    local COMMAND=$4


    ssh -i $SSH_CLUSTER_KEY -q -p $SSH_PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$USER@$IP" $COMMAND
}

scp_to_remote() {
    local FILE_ARGS=$1
    local SSH_PORT=$2
    scp -i $SSH_CLUSTER_KEY -P $SSH_PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $FILE_ARGS
}

create_master_service_file() {
    SERVICE_USER=$(yq eval '.service.default_user // "quilibrium"' $QTOOLS_CONFIG_FILE)
    SIGNATURE_CHECK=$(yq eval '.service.signature_check // ""' $QTOOLS_CONFIG_FILE)
    DEBUG=$(yq eval '.service.debug // ""' $QTOOLS_CONFIG_FILE)
    TESTNET=$(yq eval '.service.testnet // ""' $QTOOLS_CONFIG_FILE)

    # Ensure quilibrium user exists and determine correct node path
    if [ "$SERVICE_USER" == "quilibrium" ]; then
        if ! id "$SERVICE_USER" &>/dev/null; then
            log "Quilibrium user not found. Creating it..."
            qtools create-quilibrium-user
        fi
        # Use quilibrium user's node path
        QUIL_NODE_PATH_FOR_SERVICE="/home/quilibrium/ceremonyclient/node"
        # Check if quilibrium_node_path is configured
        CONFIGURED_PATH=$(yq eval '.service.quilibrium_node_path // ""' $QTOOLS_CONFIG_FILE)
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

    if [ -z "$SERVICE_USER" ]; then
        echo "Error: Failed to get service user information"
        exit 1
    fi
    echo -e "${BLUE}${INFO_ICON} Updating $QUIL_SERVICE_NAME.service file...${RESET}"
    local temp_file=$(mktemp)

    cat > "$temp_file" <<EOF
[Unit]
Description=Quilibrium Master Node Service
After=network.target
Wants=network-online.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=5
StartLimitBurst=5
User=$SERVICE_USER
Group=$QTOOLS_GROUP
WorkingDirectory=$QUIL_NODE_PATH_FOR_SERVICE
ExecStart=$LINKED_NODE_BINARY ${SIGNATURE_CHECK:+"--signature-check=false"} ${DEBUG:+"--debug"} ${TESTNET:+"--network=1"}
ExecStop=/bin/kill -s SIGINT $MAINPID
ExecReload=/bin/kill -s SIGINT $MAINPID && $LINKED_NODE_BINARY ${SIGNATURE_CHECK:+"--signature-check=false"} ${DEBUG:+"--debug"} ${TESTNET:+"--network=1"}
KillSignal=SIGINT
RestartKillSignal=SIGINT
FinalKillSignal=SIGINT

[Install]
WantedBy=multi-user.target
EOF

    if [ "$DRY_RUN" == "true" ]; then
        echo -e "${BLUE}${INFO_ICON} [DRY RUN] [ MASTER ] [ $LOCAL_IP ] Would create master service file ($MASTER_SERVICE_FILE) with the following content:${RESET}"
        cat "$temp_file"
        rm "$temp_file"
    else
        sudo mv "$temp_file" "$MASTER_SERVICE_FILE"
        sudo systemctl enable $QUIL_SERVICE_NAME
        sudo systemctl daemon-reload
        echo -e "${BLUE}${INFO_ICON} Service file created and systemd reloaded.${RESET}"
    fi
}

create_data_worker_service_file() {
    SERVICE_USER=$(yq eval '.service.default_user // "quilibrium"' $QTOOLS_CONFIG_FILE)

    # Ensure quilibrium user exists and determine correct node path
    if [ "$SERVICE_USER" == "quilibrium" ]; then
        if ! id "$SERVICE_USER" &>/dev/null; then
            log "Quilibrium user not found. Creating it..."
            qtools create-quilibrium-user
        fi
        # Use quilibrium user's node path
        QUIL_NODE_PATH_FOR_SERVICE="/home/quilibrium/ceremonyclient/node"
        # Check if quilibrium_node_path is configured
        CONFIGURED_PATH=$(yq eval '.service.quilibrium_node_path // ""' $QTOOLS_CONFIG_FILE)
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

    if [ -z "$SERVICE_USER" ]; then
        echo "Error: Failed to get service user information"
        exit 1
    fi
    SIGNATURE_CHECK=$(yq eval '.service.signature_check // ""' $QTOOLS_CONFIG_FILE)
    DEBUG=$(yq eval '.service.debug // ""' $QTOOLS_CONFIG_FILE)
    TESTNET=$(yq eval '.service.testnet // ""' $QTOOLS_CONFIG_FILE)
    echo -e "${BLUE}${INFO_ICON} Updating $DATA_WORKER_SERVICE_FILE file...${RESET}"
    local temp_file=$(mktemp)

    cat > "$temp_file" <<EOF
[Unit]
Description=Quilibrium Worker Service %i
After=network.target
Wants=network-online.target
StartLimitIntervalSec=0

[Service]
Type=simple
WorkingDirectory=$QUIL_NODE_PATH_FOR_SERVICE
Restart=on-failure
RestartSec=5
StartLimitBurst=5
User=$SERVICE_USER
Group=$QTOOLS_GROUP
ExecStart=$LINKED_NODE_BINARY --core %i ${SIGNATURE_CHECK:+"--signature-check=false"} ${DEBUG:+"--debug"} ${TESTNET:+"--network=1"}
ExecStop=/bin/kill -s SIGINT $MAINPID
ExecReload=/bin/kill -s SIGINT $MAINPID && $LINKED_NODE_BINARY --core %i ${SIGNATURE_CHECK:+"--signature-check=false"} ${DEBUG:+"--debug"} ${TESTNET:+"--network=1"}
KillSignal=SIGINT
RestartKillSignal=SIGINT
FinalKillSignal=SIGINT

[Install]
WantedBy=multi-user.target
EOF

    if [ "$DRY_RUN" == "true" ]; then
        local node_type=$(is_master == "true" && echo "MASTER" || echo "LOCAL")
        echo -e "${BLUE}${INFO_ICON} [DRY RUN] [ $node_type ] [ $LOCAL_IP ] Would create data worker service file ($DATA_WORKER_SERVICE_FILE) with the following content:${RESET}"
        cat "$temp_file"
        rm "$temp_file"
    else
        sudo mv "$temp_file" "$DATA_WORKER_SERVICE_FILE"
        sudo systemctl daemon-reload
        echo -e "${BLUE}${INFO_ICON} Service file created and systemd reloaded.${RESET}"
    fi
}

create_service_file_if_not_exists() {
    local service_file=$1
    local create_function=$2

    if [ ! -f "$service_file" ]; then
        echo -e "${BLUE}${INFO_ICON} Service file $service_file does not exist. Creating it...${RESET}"
        $create_function
    else
        echo -e "${GREEN}${CHECK_ICON} Service file $service_file already exists.${RESET}"
    fi
    sudo systemctl daemon-reload
}

enable_local_data_worker_services() {
    local START_CORE_INDEX=$1
    local END_CORE_INDEX=$2
    # start the master node
    bash -c "sudo systemctl enable $QUIL_DATA_WORKER_SERVICE_NAME\@{$START_CORE_INDEX..$END_CORE_INDEX} &> /dev/null"
}

disable_local_data_worker_services() {
    bash -c "sudo systemctl disable $QUIL_DATA_WORKER_SERVICE_NAME@.service &> /dev/null"
}

start_local_data_worker_services() {
    local START_CORE_INDEX=$1
    local END_CORE_INDEX=$2
    local LOCAL_IP=$3

    # Use base_index from config if not explicitly provided
    if [ -z "$START_CORE_INDEX" ] || [ "$START_CORE_INDEX" == "0" ]; then
        START_CORE_INDEX=$(yq eval '.data_worker_service.base_index // 1' $QTOOLS_CONFIG_FILE)
    fi

    echo -e "${BLUE}${INFO_ICON} [ LOCAL ] [ $LOCAL_IP ] Starting local data worker services on core $START_CORE_INDEX and ending with $END_CORE_INDEX${RESET}"
    enable_local_data_worker_services $START_CORE_INDEX $END_CORE_INDEX
    bash -c "sudo systemctl start $QUIL_DATA_WORKER_SERVICE_NAME\@{$START_CORE_INDEX..$END_CORE_INDEX} &> /dev/null"
}

start_single_worker_service() {
    local CORE_INDEX=$1
    if [ -z "$CORE_INDEX" ]; then
        echo -e "${RED}${ERROR_ICON} Core index is required${RESET}"
        return 1
    fi
    echo -e "${BLUE}${INFO_ICON} Starting worker service for core $CORE_INDEX${RESET}"
    sudo systemctl start ${QUIL_DATA_WORKER_SERVICE_NAME}@${CORE_INDEX}.service
}

stop_single_worker_service() {
    local CORE_INDEX=$1
    if [ -z "$CORE_INDEX" ]; then
        echo -e "${RED}${ERROR_ICON} Core index is required${RESET}"
        return 1
    fi
    echo -e "${BLUE}${INFO_ICON} Stopping worker service for core $CORE_INDEX${RESET}"
    sudo systemctl stop ${QUIL_DATA_WORKER_SERVICE_NAME}@${CORE_INDEX}.service
}

get_base_index_for_server() {
    local server_ip="${1:-$LOCAL_IP}"
    local base_index=$(yq eval ".data_worker_service.base_index // 1" $QTOOLS_CONFIG_FILE)

    # If server_ip is provided and different from local, calculate from cluster config
    if [ -n "$server_ip" ] && [ "$server_ip" != "$LOCAL_IP" ]; then
        base_index=$(calculate_server_core_index "$server_ip")
    fi

    echo "${base_index:-1}"
}

calculate_server_core_index() {
    local target_ip="$1"
    local config=$(yq eval . $QTOOLS_CONFIG_FILE)
    local servers=$(echo "$config" | yq eval '.service.clustering.servers' -)
    local server_count=$(echo "$servers" | yq eval '. | length' -)

    local cumulative_workers=0

    for ((i=0; i<server_count; i++)); do
        local server=$(echo "$servers" | yq eval ".[$i]" -)
        local server_ip=$(echo "$server" | yq eval '.ip' -)

        if [ "$server_ip" == "$target_ip" ]; then
            # Found target server - return starting index (1 for master, cumulative+1 for others)
            if [ "$(is_master)" == "true" ] && [ "$server_ip" == "$LOCAL_IP" ]; then
                echo "1"
            else
                echo $((cumulative_workers + 1))
            fi
            return
        fi

        # Add this server's worker count to cumulative
        local worker_count=$(echo "$server" | yq eval '.data_worker_count // "false"' -)
        if [ "$worker_count" == "false" ] || [ -z "$worker_count" ]; then
            # Auto-detect worker count
            if echo "$(hostname -I)" | grep -q "$server_ip" || echo "$server_ip" | grep -q "127.0.0.1"; then
                worker_count=$(($(nproc) - 1))  # Master server
            else
                worker_count=$(nproc)  # Worker server (would need SSH, but use nproc as fallback)
            fi
        fi
        worker_count=$(echo "$worker_count" | tr -cd '0-9')
        cumulative_workers=$((cumulative_workers + worker_count))
    done

    # If server not found, return 1 (default)
    echo "1"
}

get_server_info_for_core_index() {
    local core_index="$1"
    local config=$(yq eval . $QTOOLS_CONFIG_FILE)
    local servers=$(echo "$config" | yq eval '.service.clustering.servers' -)
    local server_count=$(echo "$servers" | yq eval '. | length' -)

    local cumulative_workers=0

    for ((i=0; i<server_count; i++)); do
        local server=$(echo "$servers" | yq eval ".[$i]" -)
        local server_ip=$(echo "$server" | yq eval '.ip' -)
        local remote_user=$(echo "$server" | yq eval ".user // \"$DEFAULT_USER\"" -)
        local ssh_port=$(echo "$server" | yq eval ".ssh_port // \"$DEFAULT_SSH_PORT\"" -)

        local worker_count=$(echo "$server" | yq eval '.data_worker_count // "false"' -)
        if [ "$worker_count" == "false" ] || [ -z "$worker_count" ]; then
            if echo "$(hostname -I)" | grep -q "$server_ip" || echo "$server_ip" | grep -q "127.0.0.1"; then
                worker_count=$(($(nproc) - 1))
            else
                worker_count=$(nproc)
            fi
        fi
        worker_count=$(echo "$worker_count" | tr -cd '0-9')

        local start_index=$((cumulative_workers + 1))
        if echo "$(hostname -I)" | grep -q "$server_ip" || echo "$server_ip" | grep -q "127.0.0.1"; then
            # Master server starts at 1
            start_index=1
        fi

        local end_index=$((start_index + worker_count - 1))

        if [ "$core_index" -ge "$start_index" ] && [ "$core_index" -le "$end_index" ]; then
            # Found the server that owns this core index
            local local_core=$((core_index - start_index + 1))
            echo "$server_ip|$remote_user|$ssh_port|$local_core"
            return
        fi

        cumulative_workers=$((cumulative_workers + worker_count))
    done

    # Core index not found in any server
    echo ""
}

stop_local_data_worker_services() {
    bash -c "sudo systemctl stop $QUIL_DATA_WORKER_SERVICE_NAME@*.service &> /dev/null"
}

get_cluster_ips() {
    local config=$(yq eval . $QTOOLS_CONFIG_FILE)
    local servers=$(echo "$config" | yq eval '.service.clustering.servers' -)
    local server_count=$(echo "$servers" | yq eval '. | length' -)
    local ips=()

    for ((i=0; i<server_count; i++)); do
        local server=$(echo "$servers" | yq eval ".[$i]" -)
        local ip=$(echo "$server" | yq eval '.ip' -)

        if [ -n "$ip" ] && [ "$ip" != "null" ]; then
            ips+=("$ip")
        fi
    done

    echo "${ips[@]}"
}

get_cluster_worker_count() {
    local ip="$1"
    local config=$(yq eval . $QTOOLS_CONFIG_FILE)
    local servers=$(echo "$config" | yq eval '.service.clustering.servers' -)
    local server_count=$(echo "$servers" | yq eval '. | length' -)

    for ((i=0; i<server_count; i++)); do
        local server=$(echo "$servers" | yq eval ".[$i]" -)
        local server_ip=$(echo "$server" | yq eval '.ip' -)
        if [ "$server_ip" == "$ip" ]; then
            local data_worker_count=$(echo "$server" | yq eval '.data_worker_count // "0"' -)
            echo "$data_worker_count"
            return
        fi
    done

    echo "0"
}

get_cores_to_use() {
    local ip="$1"
    local config=$(yq eval . $QTOOLS_CONFIG_FILE)
    local servers=$(echo "$config" | yq eval '.service.clustering.servers' -)
    local server_count=$(echo "$servers" | yq eval '. | length' -)

    for ((i=0; i<server_count; i++)); do
        local server=$(echo "$servers" | yq eval ".[$i]" -)
        local server_ip=$(echo "$server" | yq eval '.ip' -)
        if [ "$server_ip" == "$ip" ]; then
            local cores_to_use=$(echo "$server" | yq eval '.cores_to_use // "false"' -)
            echo "$cores_to_use"
            return
        fi
    done

    echo "0"
}

ssh_command_to_each_server() {
    local command=$1

    local config=$(yq eval . $QTOOLS_CONFIG_FILE)
    local servers=$(echo "$config" | yq eval '.service.clustering.servers' -)
    local server_count=$(echo "$servers" | yq eval '. | length' -)

    for ((i=0; i<server_count; i++)); do
        local server=$(echo "$servers" | yq eval ".[$i]" -)
        local ip=$(echo "$server" | yq eval '.ip' -)
        local remote_user=$(echo "$server" | yq eval ".user // \"$DEFAULT_USER\"" -)
        local ssh_port=$(echo "$server" | yq eval ".ssh_port // \"$DEFAULT_SSH_PORT\"" -)

        if [ -n "$ip" ] && [ "$ip" != "null" ]; then
            if [ "$DRY_RUN" == "false" ]; then
                if ! echo "$(hostname -I)" | grep -q "$ip" && [ "$ip" != "127.0.0.1" ]; then
                    echo "Running $command on $ip ($remote_user)"
                    ssh_to_remote $ip $remote_user $ssh_port "$command" &
                fi
            else
                echo "[DRY RUN] [ MASTER ] [ $LOCAL_IP ] Would run $command on $remote_user@$ip"
            fi
        fi
    done
    wait
}

copy_file_to_each_server() {
    local file_path=$1
    local destination_path=$2
    local command=$1

    local config=$(yq eval . $QTOOLS_CONFIG_FILE)
    local servers=$(echo "$config" | yq eval '.service.clustering.servers' -)
    local server_count=$(echo "$servers" | yq eval '. | length' -)

    for ((i=0; i<server_count; i++)); do
        local server=$(echo "$servers" | yq eval ".[$i]" -)
        local ip=$(echo "$server" | yq eval '.ip' -)
        local ssh_port=$(echo "$server" | yq eval ".ssh_port // \"$DEFAULT_SSH_PORT\"" -)
        local remote_user=$(echo "$server" | yq eval ".user // \"$DEFAULT_USER\"" -)

        if [ -n "$ip" ] && [ "$ip" != "null" ]; then
            if [ "$DRY_RUN" == "false" ]; then
                if ! echo "$(hostname -I)" | grep -q "$ip"; then
                    echo "Copying $file_path to $ip ($remote_user)"
                    scp_to_remote "$file_path $remote_user@$ip:$destination_path" $ssh_port
                fi
            else
                echo "[DRY RUN] [ MASTER ] [ $LOCAL_IP ] Would copy $file_path to $remote_user@$ip:$destination_path"
            fi
        fi
    done
}

ssh_command_to_server() {
    local ip=$1
    local command=$2

    local config=$(yq eval . $QTOOLS_CONFIG_FILE)
    local servers=$(echo "$config" | yq eval '.service.clustering.servers' -)
    local server_count=$(echo "$servers" | yq eval '. | length' -)

    for ((i=0; i<server_count; i++)); do
        local server=$(echo "$servers" | yq eval ".[$i]" -)
        local server_ip=$(echo "$server" | yq eval '.ip' -)

        if [ "$server_ip" == "$ip" ]; then
            local remote_user=$(echo "$server" | yq eval ".user // \"$DEFAULT_USER\"" -)
            local ssh_port=$(echo "$server" | yq eval ".ssh_port // \"$DEFAULT_SSH_PORT\"" -)
            if [ "$DRY_RUN" == "false" ]; then
                if ! echo "$(hostname -I)" | grep -q "$ip"; then
                    echo "Running $command on $ip ($remote_user)"
                    ssh_to_remote $ip $remote_user $ssh_port "$command" &
                    return
                fi
            else
                echo "[DRY RUN] [ MASTER ] [ $LOCAL_IP ] Would copy $file_path to $remote_user@$ip:$destination_path"
            fi
        fi
    done
}

restart_cluster_data_workers() {
    ssh_command_to_each_server "qtools refresh-data-workers -m"
}

update_quil_config() {
    local single_worker=$1
    config=$(yq eval . $QTOOLS_CONFIG_FILE)

    # Get the array of servers
    servers=$(echo "$config" | yq eval '.service.clustering.servers' -)

    # Ensure base P2P/Stream ports are set (2.1)
    if [ "$DRY_RUN" == "false" ]; then
        yq eval -i ".engine.dataWorkerBaseP2PPort = $WORKER_BASE_P2P_PORT" "$QUIL_CONFIG_FILE"
        yq eval -i ".engine.dataWorkerBaseStreamPort = $WORKER_BASE_STREAM_PORT" "$QUIL_CONFIG_FILE"
        # Clear existing arrays for 2.1 worker multiaddrs
        yq eval -i '.engine.dataWorkerP2PMultiaddrs = []' "$QUIL_CONFIG_FILE"
        yq eval -i '.engine.dataWorkerStreamMultiaddrs = []' "$QUIL_CONFIG_FILE"
    else
        echo -e "${BLUE}${INFO_ICON} [DRY RUN] [ MASTER ] [ $LOCAL_IP ] Would set engine.dataWorkerBaseP2PPort=$WORKER_BASE_P2P_PORT and engine.dataWorkerBaseStreamPort=$WORKER_BASE_STREAM_PORT and clear dataWorkerP2PMultiaddrs/dataWorkerStreamMultiaddrs${RESET}"
    fi

    # Initialize TOTAL_EXPECTED_DATA_WORKERS
    TOTAL_EXPECTED_DATA_WORKERS=0

    # Get the number of servers
    server_count=$(echo "$servers" | yq eval '. | length' -)

    # Loop through each server
    for ((i=0; i<server_count; i++)); do
        server=$(echo "$servers" | yq eval ".[$i]" -)
        ip=$(echo "$server" | yq eval '.ip' -)
        remote_user=$(echo "$server" | yq eval ".user // \"$DEFAULT_USER\"" -)
        ssh_port=$(echo "$server" | yq eval ".ssh_port // \"$DEFAULT_SSH_PORT\"" -)
        base_port=$(echo "$server" | yq eval ".base_port // \"$BASE_PORT\"" -)
        data_worker_count=$(echo "$server" | yq eval '.data_worker_count // "false"' -)
        cores_to_use=$(echo "$server" | yq eval '.cores_to_use // "false"' -)
        available_cores=$(nproc)

        # Skip invalid entries
        if [ -z "$ip" ] || [ "$ip" == "null" ]; then
            echo "Skipping invalid server entry: $server"
            continue
        fi

        echo "Processing server: $ip (user: $remote_user, worker count: $data_worker_count)"
        if echo "$(hostname -I)" | grep -q "$ip" || echo "$ip" | grep -q "127.0.0.1"; then
            if [ "$DRY_RUN" == "false" ]; then
                qtools config set-value service.clustering.main_ip "$ip" --quiet
                echo "Set main IP to $ip in clustering configuration"
            else
                echo -e "${BLUE}${INFO_ICON} [DRY RUN] [ MASTER ] [ $LOCAL_IP ] Would set main IP to $ip in clustering configuration${RESET}"
            fi
            # This is the master server, so subtract 1 from the total core count
            available_cores=$(($(nproc) - 1))
        else
            echo -e "${BLUE}${INFO_ICON} Getting available cores for $ip (user: $remote_user)${RESET}"
            # Get the number of available cores
            available_cores=$(ssh_to_remote $ip $remote_user $ssh_port "nproc")
        fi

        if [ "$data_worker_count" == "false" ]; then
            data_worker_count=$available_cores
        fi
        if [ "$cores_to_use" == "false" ]; then
            cores_to_use=$available_cores
        fi

        # Convert data_worker_count to integer and ensure it's not greater than available cores
        data_worker_count=$(echo "$data_worker_count" | tr -cd '0-9')

        echo "Workers for $ip: $data_worker_count (cores to use: $cores_to_use)"

        # Increment the global count
        TOTAL_EXPECTED_DATA_WORKERS=$((TOTAL_EXPECTED_DATA_WORKERS + data_worker_count))
        # Build explicit P2P and Stream multiaddrs arrays for 2.1
        for ((w=0; w<data_worker_count; w++)); do
            p2p_port=$((WORKER_BASE_P2P_PORT + w))
            stream_port=$((WORKER_BASE_STREAM_PORT + w))
            p2p_addr="/ip4/$ip/tcp/$p2p_port"
            stream_addr="/ip4/$ip/tcp/$stream_port"
            if [ "$DRY_RUN" == "false" ]; then
                yq eval -i ".engine.dataWorkerP2PMultiaddrs += \"$p2p_addr\"" "$QUIL_CONFIG_FILE"
                yq eval -i ".engine.dataWorkerStreamMultiaddrs += \"$stream_addr\"" "$QUIL_CONFIG_FILE"
            else
                echo -e "${BLUE}${INFO_ICON} [DRY RUN] [ MASTER ] [ $LOCAL_IP ] Would add $p2p_addr and $stream_addr to 2.1 worker arrays${RESET}"
            fi
        done
        if [ "$DRY_RUN" == "false" ]; then
            # Count total lines with this IP
            total_lines=$(yq eval '.engine.dataWorkerMultiaddrs[] | select(contains("'$ip'"))' "$QUIL_CONFIG_FILE" | wc -l)

            echo "Server $ip:  Total lines: $total_lines, Expected data workers: $data_worker_count"
            if [ "$total_lines" -ne "$data_worker_count" ]; then
                echo -e "\e[33mWarning: Mismatch detected for server $ip\e[0m"
                echo -e "\e[33m  - Expected $data_worker_count data workers, found $total_lines\e[0m"
            fi
        fi
    done

    # 2.1: Using explicit P2P/Stream worker arrays; no legacy validation
}

check_ssh_key_pair() {
    if [ -f "$SSH_CLUSTER_KEY" ]; then
        echo -e "${GREEN}${CHECK_ICON} SSH private key exists at $SSH_CLUSTER_KEY${RESET}"
    else
        echo -e "${RED}${WARNING_ICON} A SSH key pair is required for the master to send commands to the slave nodes.${RESET}"
        echo -e "${BLUE}${INFO_ICON} This key is used solely for cluster communication and not for any other purposes.${RESET}"
        echo -e "${BLUE}${INFO_ICON} You can generate it yourself by running the following on your master node server:${RESET}"
        echo -e "${YELLOW}ssh-keygen -t ed25519 -f $SSH_CLUSTER_KEY -N '' -C 'cluster-key'${RESET}"
        echo -e "${BLUE}${INFO_ICON} You will then need to add this public key (${SSH_CLUSTER_KEY}.pub) to the ~/.ssh/authorized_keys file on all slave servers and will automatically be used for cluster operations.${RESET}"
        read -p "Or you can enter yes to use the added helper function to generate a new SSH key pair? (y/n): " generate_key

        if [[ $generate_key =~ ^[Yy]$ ]]; then
            generate_ssh_key_pair
        else
            echo -e "${RED}${WARNING_ICON} SSH key pair is required for cluster operations. Please generate or provide a key pair.${RESET}"
            return 1
        fi
    fi

    return 0
}

generate_ssh_key_pair() {
    ssh-keygen -t ed25519 -f "$SSH_CLUSTER_KEY" -N "" -C "cluster-key"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}${CHECK_ICON} SSH key pair generated successfully at $SSH_CLUSTER_KEY${RESET}"
        echo -e "${BLUE}${INFO_ICON} Please copy the following public key to the ~/.ssh/authorized_keys file on all slave servers:${RESET}"
        cat "${SSH_CLUSTER_KEY}.pub"
        echo -e "${YELLOW}${WARNING_ICON} If you have already connected to the slave servers, you can add this key to each slave server using:${RESET}"
        echo -e "  ssh-copy-id -i ${SSH_CLUSTER_KEY}.pub user@slave_ip"
        echo -e "${BLUE}${INFO_ICON} Replace 'user' and 'slave_ip' with the appropriate values for each server.${RESET}"
    else
        echo -e "${RED}${WARNING_ICON} Failed to generate SSH key pair${RESET}"
        return 1
    fi

    return 0
}

check_server_ssh_connection() {
    local ip=$1
    local user=$2
    local ssh_port=$3
    ssh -i $SSH_CLUSTER_KEY -p $ssh_port -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no "$user@$ip" exit &>/dev/null
}

check_ssh_connections() {
    local servers=$(yq eval '.service.clustering.servers' $QTOOLS_CONFIG_FILE)
    local server_count=$(echo "$servers" | yq eval '. | length' -)

    echo -e "${BLUE}${INFO_ICON} Checking connections to all servers...${RESET}"

    for ((i=0; i<server_count; i++)); do
        local server=$(yq eval ".service.clustering.servers[$i]" $QTOOLS_CONFIG_FILE)
        local ip=$(echo "$server" | yq eval '.ip' -)
        if [ -z "$ip" ]; then
            echo -e "${RED}✗ Failed to get IP for server $i${RESET}"
            continue
        fi
        local user=$(echo "$server" | yq eval ".user // \"$DEFAULT_USER\"" -)
        local ssh_port=$(echo "$server" | yq eval ".ssh_port // \"$DEFAULT_SSH_PORT\"" -)

        if echo "$(hostname -I)" | grep -q "$ip"; then
            echo -e "${GREEN}✓ Local server $ip is reachable${RESET}"
        else
            if check_server_ssh_connection $ip $user $ssh_port; then
                echo -e "${GREEN}✓ Remote server $ip is reachable${RESET}"
            else
                echo -e "${RED}✗ Failed to connect to remote server $ip${RESET}"
            fi
        fi
    done
}

check_server_needs_provisioning() {
    local ip=$1
    local user=$2
    local ssh_port=$3

    ssh -i $SSH_CLUSTER_KEY -p $ssh_port -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no "$user@$ip" "command -v qtools" &>/dev/null
    if [ $? -ne 0 ]; then
        echo "true"
    else
        echo "false"
    fi
}

check_data_worker_services() {
    local ip=$1
    local user=$2
    local ssh_port=$3
    local data_worker_count=$4
    local base_port=$5
    local end_port=$((base_port + data_worker_count - 1))
    # Check if ports are listening using netstat
    local netstat_cmd="netstat -tuln | grep LISTEN"
    local ports_status=""

    if echo "$(hostname -I)" | grep -q "$ip"; then
        # Check locally
        ports_status=$(eval $netstat_cmd)
    else
        # Check remotely via SSH
        ports_status=$(ssh -i $SSH_CLUSTER_KEY -p $ssh_port -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no "$user@$ip" "$netstat_cmd")
    fi

    local missing_ports=()
    for ((port=base_port; port<=end_port; port++)); do
        if ! echo "$ports_status" | grep -q ":$port"; then
            missing_ports+=($port)
        fi
    done

    if [ ${#missing_ports[@]} -eq 0 ]; then
        echo -e "${GREEN}✓ All data worker ports ($base_port-$end_port) are listening on $ip${RESET}"
        return 0
    else
        echo -e "${RED}✗ Missing data worker ports on $ip: ${missing_ports[*]}${RESET}"
        return 1
    fi
}

