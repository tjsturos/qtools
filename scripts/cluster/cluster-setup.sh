#!/bin/bash

# Get the number of CPU cores
TOTAL_CORES=$(nproc)

# Set default values
DATA_WORKER_COUNT=$TOTAL_CORES
INDEX_START=1
MASTER=false
DRY_RUN=false

# Function to display usage information
usage() {
    echo "Usage: $0 [--master] [--dry-run]"
    echo "  --help               Display this help message"
    echo "  --data-worker-count  Number of workers to start (default: number of CPU cores)"
    echo "  --core-index-start   Starting index for worker cores (default: 1)"
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
        --core-index-start)
            INDEX_START="$2"
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
    echo -e "${BLUE}${INFO_ICON} [DRY RUN] Running in dry run mode, no changes will be made${RESET}"
fi

# Adjust COUNT if master is specified, but only if not all cores are used for workers
if [ "$MASTER" == "true" ] && [ "$TOTAL_CORES" -eq "$DATA_WORKER_COUNT" ]; then
    DATA_WORKER_COUNT=$((TOTAL_CORES - 1))
    echo -e "${BLUE}${INFO_ICON} Adjusting master's data worker count to $DATA_WORKER_COUNT${RESET}"
fi

create_data_worker_service_file

if [ "$MASTER" == "true" ]; then
    create_master_service_file
fi

if [ "$DRY_RUN" == "false" ]; then  
    yq eval -i ".service.clustering.local_core_start_index = $INDEX_START" $QTOOLS_CONFIG_FILE
    yq eval -i ".service.clustering.local_dataworker_count = $DATA_WORKER_COUNT" $QTOOLS_CONFIG_FILE
else
    echo -e "${BLUE}${INFO_ICON} [DRY RUN] Would set $QTOOLS_CONFIG_FILE's start_core_index to $INDEX_START and data_worker_count to $DATA_WORKER_COUNT${RESET}"
fi

START_CORE_INDEX=$INDEX_START
END_CORE_INDEX=$((INDEX_START + DATA_WORKER_COUNT - 1))

if [ "$DRY_RUN" == "false" ]; then
    echo "Enabling $QUIL_SERVICE_NAME"
    sudo systemctl enable $QUIL_SERVICE_NAME
    echo "Enabling $QUIL_DATA_WORKER_SERVICE_NAME@{$START_CORE_INDEX..$END_CORE_INDEX}"
    bash -c "sudo systemctl enable $QUIL_DATA_WORKER_SERVICE_NAME\@{$START_CORE_INDEX..$END_CORE_INDEX}"
    sudo systemctl daemon-reload
else
    echo -e "${BLUE}${INFO_ICON} [DRY RUN] Would enable local $QUIL_DATA_WORKER_SERVICE_NAME@{$START_CORE_INDEX..$END_CORE_INDEX}${RESET}"
fi

setup_remote_firewall() {
    local IP=$1
    local REMOTE_USER=$2
    local SSH_PORT=$3
    local START_INDEX=$4
    local BASE_PORT=$(yq eval '.service.clustering.base_port // 40000' $QTOOLS_CONFIG_FILE)
    local START_PORT=$((BASE_PORT + START_INDEX - 1))
    local DATA_WORKER_COUNT=$5
    local END_PORT=$((BASE_PORT + START_INDEX - 1 + DATA_WORKER_COUNT))
    local MASTER_IP=$(yq eval '.service.clustering.main_ip' $QTOOLS_CONFIG_FILE)
    if [ -z "$MASTER_IP" ]; then
        echo -e "${RED}${WARNING_ICON} Error: master_ip not found in $QTOOLS_CONFIG_FILE${RESET}"
        return 1
    fi

    echo -e "${BLUE}${INFO_ICON} Setting up remote firewall on $IP ($REMOTE_USER) for ports $START_PORT to $END_PORT${RESET}"

    if [ "$DRY_RUN" == "false" ]; then
        # Delete existing rules for the port range
        ssh_to_remote $IP $REMOTE_USER "sudo ufw delete allow $START_PORT:$END_PORT/tcp" $SSH_PORT  
        
        # Allow port range from START_INDEX to END_INDEX
        ssh_to_remote $IP $REMOTE_USER "sudo ufw allow $START_PORT:$END_PORT/tcp from $MASTER_IP" $SSH_PORT
        
        # Reload ufw to apply changes
        ssh_to_remote $IP $REMOTE_USER "sudo ufw reload" $SSH_PORT
        
        echo -e "${GREEN}${SUCCESS_ICON} Remote firewall setup completed on $IP${RESET}"
    else
        echo -e "${BLUE}${INFO_ICON} [DRY RUN] Would set up remote firewall on $IP ($USER) for ports $START_INDEX to $END_INDEX${RESET}"
    fi
}

setup_remote_data_workers() {
    local IP=$1
    local USER=$2
    local SSH_PORT=$3
    local CORE_INDEX_START=$4  
    local CORE_COUNT=$5

    if [ "$DRY_RUN" == "false" ]; then
        echo -e "${BLUE}${INFO_ICON} Configuring cluster's data workers on $IP ($USER)${RESET}"
    else
        echo -e "${BLUE}${INFO_ICON} [DRY RUN] Would configure cluster's data workers on $IP ($USER)${RESET}"
    fi

    if [ "$DRY_RUN" == "false" ]; then
        # Log the index start
        echo "Setting up remote server with core index start: $CORE_INDEX_START"
        # Log the core count
        echo "Setting up remote server with core count: $CORE_COUNT"
        ssh_to_remote $IP $USER "bash qtools setup-cluster \
            --core-index-start $CORE_INDEX_START \
            --data-worker-count $CORE_COUNT" $SSH_PORT
    else
        echo -e "${BLUE}${INFO_ICON} [DRY RUN] Would run setup-cluster.sh on $IP ($USER) with core index start of $CORE_INDEX_START and data worker count of $CORE_COUNT${RESET}"
    fi
}

copy_quil_config_to_server() {
    local ip=$1
    local user=$2
    local ssh_port=$3
    if [ "$DRY_RUN" == "false" ]; then  
        echo -e "${BLUE}${INFO_ICON} Copying $QTOOLS_CONFIG_FILE to $ip${RESET}"
        ssh_to_remote $IP $USER "mkdir -p $HOME/ceremonyclient/node/.config" $ssh_port
        scp_to_remote "$QUIL_CONFIG_FILE $user@$ip:$HOME/ceremonyclient/node/.config/config.yml" $ssh_port
    else
        echo -e "${BLUE}${INFO_ICON} [DRY RUN] Would copy $QUIL_CONFIG_FILE to $ip ($user)${RESET}"
    fi
}

copy_cluster_config_to_server() {
    local ip=$1
    local user=$2
    local ssh_port=$3
    if [ "$DRY_RUN" == "false" ]; then  
        echo -e "${BLUE}${INFO_ICON} Copying $QTOOLS_CONFIG_FILE to $ip${RESET}"
        ssh_to_remote $IP $USER "mkdir -p $HOME/qtools" $ssh_port
        scp_to_remote "$QTOOLS_CONFIG_FILE $user@$ip:$HOME/qtools/config.yml" $ssh_port
    else
        echo -e "${BLUE}${INFO_ICON} [DRY RUN] Would copy $QTOOLS_CONFIG_FILE to $ip ($user)${RESET}"
    fi
}

# Start the master and update the config
if [ "$MASTER" == "true" ]; then
    check_ssh_key_pair

    check_ssh_connections

    update_quil_config $DRY_RUN

    servers=$(yq eval '.service.clustering.servers' $QTOOLS_CONFIG_FILE)
    server_count=$(echo "$servers" | yq eval '. | length' -)

    # create a temporary directory for the files to be copied
    REMOTE_INDEX_START=$INDEX_START

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
            available_cores=$(ssh_to_remote $ip $remote_user "nproc")
        fi

        if [ "$data_worker_count" == "false" ] || [ "$data_worker_count" -gt "$available_cores" ]; then
            data_worker_count=$available_cores
            echo "Setting data_worker_count to available cores: $data_worker_count"
        fi

        echo -e "${BLUE}${INFO_ICON} Configuring server $remote_user@$ip with $data_worker_count data workers${RESET}"

        if ! echo "$(hostname -I)" | grep -q "$ip"; then
            copy_quil_config_to_server "$ip" "$remote_user"
            copy_cluster_config_to_server "$ip" "$remote_user"
            setup_remote_data_workers "$ip" "$remote_user" "$ssh_port" "$REMOTE_INDEX_START" "$data_worker_count" &
            # Call the function to set up the remote firewall
            setup_remote_firewall "$ip" "$remote_user" "$ssh_port" "$REMOTE_INDEX_START" "$data_worker_count"
        fi
        REMOTE_INDEX_START=$((REMOTE_INDEX_START + data_worker_count))
    done
fi

wait