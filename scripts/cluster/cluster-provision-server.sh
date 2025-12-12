#!/bin/bash
# HELP: Provision a blank server from scratch for cluster setup
# PARAM: --ip <ip>: Server IP address
# PARAM: --user <user>: SSH user (default: from config)
# PARAM: --ssh-port <port>: SSH port (default: 22)
# PARAM: --worker-count <count>: Number of workers for this server
# PARAM: --base-index <index>: Starting core index for this server
# PARAM: --dry-run: Dry run mode
# Usage: qtools cluster-provision-server --ip 192.168.1.10 --user ubuntu --worker-count 20

source $QTOOLS_PATH/scripts/cluster/utils.sh

SERVER_IP=""
SERVER_USER=""
SSH_PORT=""
WORKER_COUNT=""
BASE_INDEX=""
DRY_RUN=false
PEER_ID=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --ip)
            SERVER_IP="$2"
            shift 2
            ;;
        --user)
            SERVER_USER="$2"
            shift 2
            ;;
        --ssh-port)
            SSH_PORT="$2"
            shift 2
            ;;
        --worker-count)
            WORKER_COUNT="$2"
            shift 2
            ;;
        --base-index)
            BASE_INDEX="$2"
            shift 2
            ;;
        --peer-id)
            PEER_ID="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ -z "$SERVER_IP" ]; then
    echo -e "${RED}${ERROR_ICON} Error: --ip is required${RESET}"
    exit 1
fi

# Set defaults
SERVER_USER=${SERVER_USER:-$DEFAULT_USER}
SSH_PORT=${SSH_PORT:-$DEFAULT_SSH_PORT}

# Provision the server
# Note: check_server_needs_provisioning() is defined in utils.sh
provision_server() {
    local ip=$1
    local user=$2
    local ssh_port=$3
    local worker_count=$4
    local base_index=$5

    echo -e "${BLUE}${INFO_ICON} Provisioning server $user@$ip:$ssh_port${RESET}"

    if [ "$DRY_RUN" == "true" ]; then
        echo -e "${BLUE}${INFO_ICON} [DRY RUN] Would provision server $ip${RESET}"
        return 0
    fi

    # Step 1: Check SSH connection
    if ! check_server_ssh_connection "$ip" "$user" "$ssh_port"; then
        echo -e "${RED}${ERROR_ICON} Failed to connect to $ip ($user) on port $ssh_port${RESET}"
        return 1
    fi

    # Step 2: Install qtools (clone repo)
    echo -e "${BLUE}${INFO_ICON} Installing qtools on remote server...${RESET}"
    ssh_to_remote "$ip" "$user" "$ssh_port" "if [ ! -d ~/qtools ]; then git clone https://github.com/tjsturos/qtools.git ~/qtools; fi"

    # Step 3: Initialize qtools
    echo -e "${BLUE}${INFO_ICON} Initializing qtools on remote server...${RESET}"
    ssh_to_remote "$ip" "$user" "$ssh_port" "cd ~/qtools && ./qtools.sh init"

    # Step 4: Copy master config as template
    echo -e "${BLUE}${INFO_ICON} Copying master config to remote server...${RESET}"
    scp_to_remote "$QTOOLS_CONFIG_FILE $user@$ip:~/qtools/config.yml" $ssh_port

    # Step 5: Modify remote config
    echo -e "${BLUE}${INFO_ICON} Modifying remote server config...${RESET}"
    ssh_to_remote "$ip" "$user" "$ssh_port" "yq eval -i '.data_worker_service.base_index = $base_index' ~/qtools/config.yml"
    ssh_to_remote "$ip" "$user" "$ssh_port" "yq eval -i '.service.clustering.enabled = true' ~/qtools/config.yml"
    ssh_to_remote "$ip" "$user" "$ssh_port" "yq eval -i '.service.clustering.local_data_worker_count = $worker_count' ~/qtools/config.yml"

    # Determine local_only setting
    local local_only=$(yq eval '.service.clustering.local_only // false' $QTOOLS_CONFIG_FILE)
    ssh_to_remote "$ip" "$user" "$ssh_port" "yq eval -i '.service.clustering.local_only = $local_only' ~/qtools/config.yml"

    # Step 6: Complete install
    echo -e "${BLUE}${INFO_ICON} Running complete install on remote server...${RESET}"
    local install_cmd="cd ~/qtools && ./qtools.sh complete-install"
    if [ -n "$PEER_ID" ]; then
        install_cmd="$install_cmd --peer-id $PEER_ID"
    fi
    ssh_to_remote "$ip" "$user" "$ssh_port" "$install_cmd"

    # Step 7: Copy keys.yml
    if [ -f "$QUIL_KEYS_FILE" ]; then
        echo -e "${BLUE}${INFO_ICON} Copying keys.yml to remote server...${RESET}"
        ssh_to_remote "$ip" "$user" "$ssh_port" "mkdir -p ~/ceremonyclient/node/.config"
        scp_to_remote "$QUIL_KEYS_FILE $user@$ip:~/ceremonyclient/node/.config/keys.yml" $ssh_port
    fi

    # Step 8: Copy config.yml (quil config)
    if [ -f "$QUIL_CONFIG_FILE" ]; then
        echo -e "${BLUE}${INFO_ICON} Copying quil config.yml to remote server...${RESET}"
        ssh_to_remote "$ip" "$user" "$ssh_port" "mkdir -p ~/ceremonyclient/node/.config"
        scp_to_remote "$QUIL_CONFIG_FILE $user@$ip:~/ceremonyclient/node/.config/config.yml" $ssh_port
    fi

    # Step 9: Setup clustering
    echo -e "${BLUE}${INFO_ICON} Setting up clustering on remote server...${RESET}"
    ssh_to_remote "$ip" "$user" "$ssh_port" "cd ~/qtools && ./qtools.sh cluster-setup --cores-to-use $worker_count"

    # Step 10: Copy SSH key
    echo -e "${BLUE}${INFO_ICON} Ensuring cluster SSH key is authorized...${RESET}"
    if [ -f "${SSH_CLUSTER_KEY}.pub" ]; then
        ssh-copy-id -i "${SSH_CLUSTER_KEY}.pub" -p "$ssh_port" "$user@$ip" 2>/dev/null || true
    fi

    # Step 11: Verify installation
    echo -e "${BLUE}${INFO_ICON} Verifying installation...${RESET}"
    if ssh_to_remote "$ip" "$user" "$ssh_port" "command -v qtools" &>/dev/null; then
        echo -e "${GREEN}${CHECK_ICON} Server $ip successfully provisioned${RESET}"
    else
        echo -e "${RED}${ERROR_ICON} Verification failed for server $ip${RESET}"
        return 1
    fi
}

# Main execution
if [ -z "$BASE_INDEX" ]; then
    BASE_INDEX=$(calculate_server_core_index "$SERVER_IP")
fi

if [ -z "$WORKER_COUNT" ]; then
    WORKER_COUNT=$(get_cluster_worker_count "$SERVER_IP")
    if [ "$WORKER_COUNT" == "0" ] || [ -z "$WORKER_COUNT" ]; then
        echo -e "${RED}${ERROR_ICON} Error: Worker count not specified and not found in config${RESET}"
        exit 1
    fi
fi

provision_server "$SERVER_IP" "$SERVER_USER" "$SSH_PORT" "$WORKER_COUNT" "$BASE_INDEX"
