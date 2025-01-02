#!/bin/bash

# Get the number of CPU cores
TOTAL_CORES=$(nproc)

# Set default values
MASTER=false
DRY_RUN=false
LOCAL_IP=$(get_local_ip)
LOCAL_ONLY=$(yq eval ".service.clustering.local_only" $QTOOLS_CONFIG_FILE)
DATA_WORKER_COUNT=$(get_cluster_worker_count "$LOCAL_IP")
SKIP_FIREWALL=false

# Function to display usage information
usage() {
    echo "Usage: $0 [--master] [--dry-run]"
    echo "  --help               Display this help message"
    echo "  --data-worker-count  Number of workers to start (default: number of CPU cores)"
    echo "  --dry-run            Dry run mode (default: false)"
    echo "  --skip-firewall      Skip firewall setup (default: false)"
    echo "  --master             Run a master node as one of this CPU's cores"
    exit 1
}

if [ "$IS_CLUSTERING_ENABLED" == "false" ]; then
    echo -e "${RED}${WARNING_ICON} Clustering is not enabled in $QTOOLS_CONFIG_FILE${RESET}"
    echo -e "${BLUE}${INFO_ICON} Please enable clustering in $QTOOLS_CONFIG_FILE before running this script${RESET}"
    exit 1
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-firewall)
            SKIP_FIREWALL=true
            shift
            ;;
        --help)
            usage
            ;;
        --data-worker-count)
            DATA_WORKER_COUNT="$2"
            shift 2
            ;;
        --master)
            MASTER=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done


if [ "$DATA_WORKER_COUNT" == "0" ] && [ "$(is_master)" == "false" ]; then
    DATA_WORKER_COUNT=$TOTAL_CORES
fi

if [ "$DRY_RUN" == "true" ]; then
    echo -e "${BLUE}${INFO_ICON} [DRY RUN] [ LOCAL ] [ $LOCAL_IP ] Running in dry run mode, no changes will be made${RESET}"
fi

# Check if data worker service file exists

if [ ! -f "$DATA_WORKER_SERVICE_FILE" ] && [ "$DATA_WORKER_COUNT" -gt 0 ]; then
    echo -e "${BLUE}${INFO_ICON} Creating data worker service file${RESET}"
    if [ "$DRY_RUN" == "false" ]; then
        create_data_worker_service_file
        echo -e "${GREEN}${CHECK_ICON} Created data worker service file at $DATA_WORKER_SERVICE_FILE${RESET}"
    else
        echo -e "${BLUE}${INFO_ICON} [DRY RUN] Would create data worker service file at $DATA_WORKER_SERVICE_FILE${RESET}"
    fi
fi


# Check if there are any servers configured
server_count=$(yq eval '.service.clustering.servers | length' $QTOOLS_CONFIG_FILE)

if [ "$server_count" -eq 0 ]; then
    echo -e "${RED}${WARNING_ICON} No servers configured in $QTOOLS_CONFIG_FILE${RESET}"
    echo -e "${BLUE}${INFO_ICON} Please add server configurations to the clustering section before running this script${RESET}"
    exit 1
fi

update_local_quil_config() {
    local data_worker_count=$1
    if [ "$DRY_RUN" == "false" ]; then
        yq eval -i ".engine.dataWorkerMultiaddrs = []" $QUIL_CONFIG_FILE
    else
        echo -e "${BLUE}${INFO_ICON} [DRY RUN] [ LOCAL ] [ $LOCAL_IP ] Would set $LOCAL_IP's $QUIL_CONFIG_FILE's engine.dataWorkerMultiaddrs to []${RESET}"
    fi

    for ((i=0; i<$DATA_WORKER_COUNT; i++)); do
        local addr="/ip4/$LOCAL_IP/tcp/$((BASE_PORT + $i))"
        if [ "$DRY_RUN" == "false" ]; then
            yq eval -i ".engine.dataWorkerMultiaddrs += \"$addr\"" "$QUIL_CONFIG_FILE"
        else
            echo -e "${BLUE}${INFO_ICON} [DRY RUN] [ LOCAL ] [ $LOCAL_IP ] Would add $addr to $QUIL_CONFIG_FILE's engine.dataWorkerMultiaddrs${RESET}"
        fi
    done
}

if [ "$DRY_RUN" == "false" ]; then  
    yq eval -i ".service.clustering.local_data_worker_count = $DATA_WORKER_COUNT" $QTOOLS_CONFIG_FILE
    echo -e "${BLUE}${INFO_ICON} [ LOCAL ] [ $LOCAL_IP ] Setting this server's data_worker_count to $DATA_WORKER_COUNT${RESET}"
    update_local_quil_config $DATA_WORKER_COUNT
else
    echo -e "${BLUE}${INFO_ICON} [DRY RUN] [ LOCAL ] [ $LOCAL_IP ] Would set $QTOOLS_CONFIG_FILE's data_worker_count to $DATA_WORKER_COUNT${RESET}"
fi

if [ "$DRY_RUN" == "false" ]; then
    if [ "$(is_master)" == "true" ]; then
        echo -e "${BLUE}${INFO_ICON} Enabling $QUIL_SERVICE_NAME on master node${RESET}"
        sudo systemctl enable $QUIL_SERVICE_NAME &> /dev/null
    else
        echo -e "${BLUE}${INFO_ICON} Disabling $QUIL_SERVICE_NAME on non-master node${RESET}"
        sudo systemctl stop $QUIL_SERVICE_NAME &> /dev/null
        sudo systemctl disable $QUIL_SERVICE_NAME &> /dev/null
    fi
    echo -e "${BLUE}${INFO_ICON} Resetting any existing dataworker services${RESET}"
    
    stop_local_data_worker_services
    disable_local_data_worker_services

    if [ "$DATA_WORKER_COUNT" -gt 0 ]; then
        echo "Enabling $QUIL_DATA_WORKER_SERVICE_NAME@{1..$DATA_WORKER_COUNT}"
        enable_local_data_worker_services 1 $DATA_WORKER_COUNT
    fi
    sudo systemctl daemon-reload
else
    echo -e "${BLUE}${INFO_ICON} [DRY RUN] [ LOCAL ] [ $LOCAL_IP ] Would enable local $QUIL_DATA_WORKER_SERVICE_NAME@{1..$DATA_WORKER_COUNT}${RESET}"
fi

setup_remote_firewall() {
    local IP=$1
    local REMOTE_USER=$2
    local SSH_PORT=$3
    local DATA_WORKER_COUNT=$4

    local END_PORT=$((BASE_PORT + DATA_WORKER_COUNT - 1))
    local MASTER_IP=$(yq eval '.service.clustering.main_ip' $QTOOLS_CONFIG_FILE)
    if [ -z "$MASTER_IP" ] && [ "$DRY_RUN" == "false" ]; then
        echo -e "${RED}${WARNING_ICON} Warning: .service.clustering.main_ip is not set in $QTOOLS_CONFIG_FILE${RESET}"
        echo -e "${BLUE}${INFO_ICON} Skipping firewall setup for this server${RESET}"
        return 1
    fi

    echo -e "${BLUE}${INFO_ICON} Setting up remote firewall on $IP ($REMOTE_USER) for ports $BASE_PORT to $END_PORT${RESET}"

    if [ "$DRY_RUN" == "false" ]; then
        # Check if UFW is enabled
        ufw_status=$(ssh_to_remote $IP $REMOTE_USER $SSH_PORT "sudo ufw status" | grep -i "Status: active")
        if [ -z "$ufw_status" ]; then
            echo -e "${YELLOW}${WARNING_ICON} Warning: UFW is not enabled on $IP. Skipping firewall setup.${RESET}"
            echo -e "${BLUE}${INFO_ICON} If you enable UFW on the remote server, run this script again.${RESET}"
        else
            # Remove any existing rules for these ports
            # ssh_to_remote $IP $REMOTE_USER $SSH_PORT "sudo ufw status numbered | grep '$BASE_PORT' | cut -d']' -f1 | tac | xargs -I {} sudo ufw --force delete {}"
            ssh_to_remote $IP $REMOTE_USER $SSH_PORT "sudo ufw allow proto tcp from $MASTER_IP to any port $BASE_PORT:$END_PORT" &> /dev/null
            
            # Reload ufw to apply changes
            ssh_to_remote $IP $REMOTE_USER $SSH_PORT "sudo ufw reload" &> /dev/null
            
            echo -e "${GREEN}${CHECK_ICON} Remote firewall setup completed on $IP${RESET}"
        fi
        
    else
        echo -e "${BLUE}${INFO_ICON} [DRY RUN] [ MASTER ] [ $LOCAL_IP ] Would set up remote firewall on $IP ($USER) for ports $BASE_PORT-$END_PORT${RESET}"
    fi
}

setup_remote_data_workers() {
    local IP=$1
    local USER=$2
    local SSH_PORT=$3
    local CORE_COUNT=$4


    if [ "$DRY_RUN" == "false" ]; then
        echo -e "${BLUE}${INFO_ICON} Configuring cluster's data workers on $IP ($USER)${RESET}"
        # Log the core count
        echo "Setting up remote server with core count: $CORE_COUNT"
        ssh_to_remote $IP $USER $SSH_PORT "qtools cluster-setup --data-worker-count $CORE_COUNT"
    else
        echo -e "${BLUE}${INFO_ICON} [DRY RUN] [ MASTER ] [ $LOCAL_IP ] Would configure cluster's data workers on $IP ($USER)${RESET}"
        echo -e "${BLUE}${INFO_ICON} [DRY RUN] [ MASTER ] [ $LOCAL_IP ] Would run setup-cluster.sh on $IP ($USER) with data worker count of $CORE_COUNT${RESET}"
    fi
}

copy_quil_config_to_server() {
    local IP=$1
    local REMOTE_USER=$2
    local SSH_PORT=$3
    if [ "$DRY_RUN" == "false" ]; then  
        echo -e "${BLUE}${INFO_ICON} Copying $QUIL_CONFIG_FILE to $IP ($REMOTE_USER)${RESET}"
        ssh_to_remote $IP $REMOTE_USER $SSH_PORT "mkdir -p ~/ceremonyclient/node/.config"
        scp_to_remote "$QUIL_CONFIG_FILE $REMOTE_USER@$IP:~/ceremonyclient/node/.config/config.yml" $SSH_PORT &> /dev/null
    else
        echo -e "${BLUE}${INFO_ICON} [DRY RUN] [ MASTER ] [ $LOCAL_IP ] Would copy $QUIL_CONFIG_FILE to $IP ($REMOTE_USER)${RESET}"
    fi
}

copy_quil_keys_to_server() {
    local IP=$1
    local REMOTE_USER=$2
    local SSH_PORT=$3
    if [ "$DRY_RUN" == "false" ]; then  
        echo -e "${BLUE}${INFO_ICON} Copying $QUIL_KEYS_FILE to $IP ($REMOTE_USER)${RESET}"
        ssh_to_remote $IP $REMOTE_USER $SSH_PORT "mkdir -p ~/ceremonyclient/node/.config" &> /dev/null
        scp_to_remote "$QUIL_KEYS_FILE $REMOTE_USER@$IP:~/ceremonyclient/node/.config/keys.yml" $SSH_PORT &> /dev/null
    else
        echo -e "${BLUE}${INFO_ICON} [DRY RUN] [ MASTER ] [ $LOCAL_IP ] Would copy $QUIL_KEYS_FILE to $IP ($REMOTE_USER)${RESET}"
    fi
}

copy_cluster_config_to_server() {
    local IP=$1
    local REMOTE_USER=$2
    local SSH_PORT=$3
    if [ "$DRY_RUN" == "false" ]; then  
        echo -e "${BLUE}${INFO_ICON} Copying $QTOOLS_CONFIG_FILE to $IP ($REMOTE_USER)${RESET}"
        ssh_to_remote $IP $REMOTE_USER $SSH_PORT "mkdir -p ~/qtools" 
        scp_to_remote "$QTOOLS_CONFIG_FILE $REMOTE_USER@$IP:~/qtools/config.yml" $SSH_PORT &> /dev/null
    else
        echo -e "${BLUE}${INFO_ICON} [DRY RUN] [ MASTER ] [ $LOCAL_IP ] Would copy $QTOOLS_CONFIG_FILE to $IP ($REMOTE_USER)${RESET}"
    fi
}

add_remote_server_hardware_info() {
    local index=$1
    local IP=$2
    local REMOTE_USER=$3
    local SSH_PORT=$4
    local CORE_COUNT=$5
    local HARDWARE_INFO=$(ssh_to_remote $IP $REMOTE_USER $SSH_PORT "qtools hardware-info -s")
    yq eval -i ".service.clustering.servers[$index].hardware_info = \"$HARDWARE_INFO\"" $QTOOLS_CONFIG_FILE
}

handle_server() {
    local index=$1
    local SERVER=$(yq eval ".service.clustering.servers[$index]" $QTOOLS_CONFIG_FILE)
    local SERVER_IP=$(echo "$SERVER" | yq eval '.ip' -)
    local REMOTE_USER=$(echo "$SERVER" | yq eval ".user // \"$DEFAULT_USER\"" -)
    local SSH_PORT=$(echo "$SERVER" | yq eval ".ssh_port // \"$DEFAULT_SSH_PORT\"" -)
    local CORE_COUNT=$(echo "$SERVER" | yq eval '.data_worker_count // "false"' -)

    local IS_LOCAL_SERVER=$(echo "$(hostname -I)" | grep -q "$SERVER_IP" || echo "$SERVER_IP" | grep -q "127.0.0.1" && echo "true" || echo "false")

    if [ "$IS_LOCAL_SERVER" == "false" ]; then
        if ! check_server_ssh_connection $SERVER_IP $REMOTE_USER $SSH_PORT; then
            echo -e "${RED}${WARNING_ICON} Failed to connect to $SERVER_IP ($REMOTE_USER) on port $SSH_PORT${RESET}"
            echo -e "${BLUE}${INFO_ICON} Skipping server setup for $SERVER_IP ($REMOTE_USER)${RESET}"
            return
        fi
    else
        echo "Skipping SSH check for $SERVER_IP ($REMOTE_USER) because it is local"
    fi

    if [[ "$CORE_COUNT" == "false" ]]; then
        if [ "$IS_LOCAL_SERVER" == "true" ] ; then
            available_cores=$(($(nproc) - 1))
        else
            echo "Getting available cores for $SERVER_IP (user: $REMOTE_USER)"
            # Get the number of available cores
            available_cores=$(ssh_to_remote $SERVER_IP $REMOTE_USER $SSH_PORT "nproc")
        fi
    fi

    echo -e "${BLUE}${INFO_ICON} Configuring server $REMOTE_USER@$SERVER_IP with $CORE_COUNT data workers${RESET}"

    if [ "$IS_LOCAL_SERVER" == "false" ]; then
        copy_quil_config_to_server "$SERVER_IP" "$REMOTE_USER" "$SSH_PORT" 
        copy_quil_keys_to_server "$SERVER_IP" "$REMOTE_USER" "$SSH_PORT" 
        copy_cluster_config_to_server "$SERVER_IP" "$REMOTE_USER" "$SSH_PORT" 
        setup_remote_data_workers "$SERVER_IP" "$REMOTE_USER" "$SSH_PORT" "$CORE_COUNT" 
        # Call the function to set up the remote firewall
        if [ "$SKIP_FIREWALL" == "false" ]; then
            setup_remote_firewall "$SERVER_IP" "$REMOTE_USER" "$SSH_PORT" "$CORE_COUNT" 
        fi
        add_remote_server_hardware_info "$index" "$SERVER_IP" "$REMOTE_USER" "$SSH_PORT" "$CORE_COUNT"
    fi
}

# Start the master and update the config
if [ "$MASTER" == "true" ]; then

    if [ "$LOCAL_ONLY" != "true" ]; then
        check_ssh_key_pair
    fi

    update_quil_config 

    servers=$(yq eval '.service.clustering.servers' $QTOOLS_CONFIG_FILE)
    server_count=$(echo "$servers" | yq eval '. | length' -)

    for ((server_index=0; server_index<$server_count; server_index++)); do
        handle_server "$server_index" &
    done
fi
wait

if [ "$DRY_RUN" == "false" ] && [ "$(is_master)" == "true" ]; then
    echo -e "${GREEN}${CHECK_ICON} Cluster setup completed. Run 'qtools cluster-start' or 'qtools start' to start the cluster.${RESET}"
fi
