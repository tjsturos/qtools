#!/bin/bash

# Get the number of CPU cores
TOTAL_CORES=$(nproc)

# Set default values
MASTER=false
DRY_RUN=false
LOCAL_IP=$(get_local_ip)

DATA_WORKER_COUNT=$(get_cluster_worker_count "$LOCAL_IP")
if [ "$DATA_WORKER_COUNT" == "0" ]; then
    DATA_WORKER_COUNT=$TOTAL_CORES
fi

# Function to display usage information
usage() {
    echo "Usage: $0 [--master] [--dry-run]"
    echo "  --help               Display this help message"
    echo "  --data-worker-count  Number of workers to start (default: number of CPU cores)"
    echo "  --dry-run            Dry run mode (default: false)"
    echo "  --master             Run a master node as one of this CPU's cores"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
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

# Validate COUNT
if ! [[ "$DATA_WORKER_COUNT" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: --data-worker-count must be a non-zero unsigned integer"
    exit 1
fi

if [ "$DRY_RUN" == "true" ]; then
    echo -e "${BLUE}${INFO_ICON} [DRY RUN] [ LOCAL ] [ $LOCAL_IP ] Running in dry run mode, no changes will be made${RESET}"
fi

# Adjust COUNT if master is specified, but only if not all cores are used for workers
if [ "$MASTER" == "true" ] && [ "$TOTAL_CORES" -eq "$DATA_WORKER_COUNT" ]; then
    DATA_WORKER_COUNT=$((TOTAL_CORES - 1))
    echo -e "${BLUE}${INFO_ICON} Adjusting master's data worker count to $DATA_WORKER_COUNT${RESET}"
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
        if [ "$DRY_RUN" == "false" ]; then
            local addr="/ip4/$LOCAL_IP/tcp/$((BASE_PORT + $i))"
            yq eval -i ".engine.dataWorkerMultiaddrs += \"$addr\"" "$QUIL_CONFIG_FILE"
        else
            echo -e "${BLUE}${INFO_ICON} [DRY RUN] [ LOCAL ] [ $LOCAL_IP ] Would add /ip4/$LOCAL_IP/tcp/$(($BASE_PORT + $i)) to $QUIL_CONFIG_FILE's engine.dataWorkerMultiaddrs${RESET}"
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
        sudo systemctl enable $QUIL_SERVICE_NAME
    else
        echo -e "${BLUE}${INFO_ICON} Disabling $QUIL_SERVICE_NAME on non-master node${RESET}"
        sudo systemctl disable $QUIL_SERVICE_NAME
    fi
    echo -e "${BLUE}${INFO_ICON} Resetting any existing dataworker services${RESET}"
    disable_local_data_worker_services

    echo "Enabling $QUIL_DATA_WORKER_SERVICE_NAME@{1..$DATA_WORKER_COUNT}"
    enable_local_data_worker_services 1 $DATA_WORKER_COUNT
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
            ssh_to_remote $IP $REMOTE_USER $SSH_PORT "sudo ufw allow proto tcp from $MASTER_IP to any port $BASE_PORT:$END_PORT" 
            
            # Reload ufw to apply changes
            ssh_to_remote $IP $REMOTE_USER $SSH_PORT "sudo ufw reload"
            
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
        scp_to_remote "$QUIL_CONFIG_FILE $REMOTE_USER@$IP:~/ceremonyclient/node/.config/config.yml" $SSH_PORT
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
        ssh_to_remote $IP $REMOTE_USER $SSH_PORT "mkdir -p ~/ceremonyclient/node/.config"
        scp_to_remote "$QUIL_KEYS_FILE $REMOTE_USER@$IP:~/ceremonyclient/node/.config/keys.yml" $SSH_PORT
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
        scp_to_remote "$QTOOLS_CONFIG_FILE $REMOTE_USER@$IP:~/qtools/config.yml" $SSH_PORT
    else
        echo -e "${BLUE}${INFO_ICON} [DRY RUN] [ MASTER ] [ $LOCAL_IP ] Would copy $QTOOLS_CONFIG_FILE to $IP ($REMOTE_USER)${RESET}"
    fi
}

# Start the master and update the config
if [ "$MASTER" == "true" ]; then
    check_ssh_key_pair

    check_ssh_connections

    update_quil_config $DRY_RUN

    servers=$(yq eval '.service.clustering.servers' $QTOOLS_CONFIG_FILE)
    server_count=$(echo "$servers" | yq eval '. | length' -)

    echo "Setting main_ip to $LOCAL_IP"
    yq eval -i ".service.clustering.main_ip = \"$LOCAL_IP\"" $QTOOLS_CONFIG_FILE

    for ((i=0; i<$server_count; i++)); do
        server=$(yq eval ".service.clustering.servers[$i]" $QTOOLS_CONFIG_FILE)
        ip=$(echo "$server" | yq eval '.ip' -)
        ssh_port=$(echo "$server" | yq eval ".ssh_port // \"$DEFAULT_SSH_PORT\"" -)
        remote_user=$(echo "$server" | yq eval ".user // \"$DEFAULT_USER\"" -)
        data_worker_count=$(echo "$server" | yq eval '.data_worker_count // "false"' -)

        if echo "$(hostname -I)" | grep -q "$ip"; then
            available_cores=$(($(nproc) - 1))
        else
            echo "Getting available cores for $ip (user: $remote_user)"
            # Get the number of available cores
            available_cores=$(ssh_to_remote $ip $remote_user $ssh_port "nproc")
        fi

        if [ "$data_worker_count" == "false" ] || [ "$data_worker_count" -gt "$available_cores" ]; then
            data_worker_count=$available_cores
            echo "Setting data_worker_count to available cores: $data_worker_count"
        fi

        echo -e "${BLUE}${INFO_ICON} Configuring server $remote_user@$ip with $data_worker_count data workers${RESET}"

        if ! echo "$(hostname -I)" | grep -q "$ip"; then
            copy_quil_config_to_server "$ip" "$remote_user" "$ssh_port"
            copy_quil_keys_to_server "$ip" "$remote_user" "$ssh_port"
            copy_cluster_config_to_server "$ip" "$remote_user" "$ssh_port"
            setup_remote_data_workers "$ip" "$remote_user" "$ssh_port" "$data_worker_count" &
            # Call the function to set up the remote firewall
            setup_remote_firewall "$ip" "$remote_user" "$ssh_port" "$data_worker_count"
        fi
    done
fi

wait
qtools toggle-cluster-mode --on
echo -e "${GREEN}${CHECK_ICON} Cluster setup completed. Run 'qtools cluster-start' or 'qtools start' to start the cluster.${RESET}"