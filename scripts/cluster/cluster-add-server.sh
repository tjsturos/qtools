#!/bin/bash

# Default values
BASE_PORT=$(yq eval ".service.clustering.base_port // \"$BASE_PORT\"" $QTOOLS_CONFIG_FILE)
DRY_RUN=false

SERVERS=()
# Parse command line arguments
while [[ $# -gt 0 ]]; do
    echo "Processing argument: $1"
    case $1 in
        --base-port)
            BASE_PORT="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            SERVERS+=("$1")
            shift
            ;;
    esac
done

if [ -z "$BASE_PORT" ]; then
    echo -e "${RED}${ERROR_ICON} Error: Base port not specified in config or via --base-port parameter${RESET}"
    exit 1
else 
    echo -e "${GREEN}${CHECK_ICON} Base port set to $BASE_PORT${RESET}"
fi


# Function to add a server to the cluster configuration
add_server_to_config() {
    local ip=$1
    local ssh_port=${2:-$DEFAULT_SSH_PORT}  # Default SSH port is 22 if not specified
    local user=${3:-$DEFAULT_USER}   # Default user is the current user if not specified
    local worker_count=${4:-null}

    # Check if the server already exists in the config
    if yq eval ".service.clustering.servers[] | select(.ip == \"$ip\")" "$QTOOLS_CONFIG_FILE" | grep -q .; then
        echo -e "${YELLOW}${WARNING_ICON} Server $ip already exists in the configuration. Removing existing entry.${RESET}"
        # Remove that entry from the config
        yq eval -i "del(.service.clustering.servers[] | select(.ip == \"$ip\"))" "$QTOOLS_CONFIG_FILE"
        if yq eval ".service.clustering.servers[] | select(.ip == \"$ip\")" "$QTOOLS_CONFIG_FILE" | grep -q .; then
            echo -e "${RED}${ERROR_ICON} Failed to remove existing server $ip from the configuration.${RESET}"
            exit 1
        fi
    fi

    # Add the new server to the configuration
    if [ "$worker_count" != "null" ]; then
        yq eval -i ".service.clustering.servers += {\"ip\": \"$ip\", \"ssh_port\": $ssh_port, \"user\": \"$user\", \"data_worker_count\": $worker_count}" "$QTOOLS_CONFIG_FILE"
        echo -e "${GREEN}${CHECK_ICON} Added server $user@$ip:$ssh_port with $worker_count workers to the cluster configuration.${RESET}"
    else
        yq eval -i ".service.clustering.servers += {\"ip\": \"$ip\", \"ssh_port\": $ssh_port, \"user\": \"$user\"}" "$QTOOLS_CONFIG_FILE"
        echo -e "${GREEN}${CHECK_ICON} Added server $user@$ip:$ssh_port to the cluster configuration.${RESET}"
    fi
}

# Main script execution
if [ $# -eq 0 ]; then
    echo -e "${RED}${ERROR_ICON} Error: No IP addresses provided.${RESET}"
    echo "Usage: $0 <ip>[:<ssh-port>][/worker-count] [ip2[:<ssh-port>][/worker-count]] ..."
    exit 1
fi



# Loop through all provided IP addresses
for arg in "${SERVERS[@]}"; do
    # Parse the argument into components
    if [[ $arg =~ ^([^@]+@)?([^:/]+)(:([0-9]+))?(/([0-9]+))?$ ]]; then
        user="${BASH_REMATCH[1]%@}"
        [ -z "$user" ] && user="$DEFAULT_USER"
        ip="${BASH_REMATCH[2]}"
        ssh_port="${BASH_REMATCH[4]:-$DEFAULT_SSH_PORT}"
        worker_count="${BASH_REMATCH[6]}"
        
        if [ -n "$worker_count" ]; then
            echo -e "${BLUE}${INFO_ICON} Processing server: $user@$ip (port: $ssh_port, workers: $worker_count)${RESET}"
            add_server_to_config "$ip" "$ssh_port" "$user" "$worker_count"
            for ((i=0; i<$worker_count; i++)); do
                yq eval -i ".engine.dataWorkerMultiaddrs += \"/ip4/$ip/tcp/$((BASE_PORT + i))\"" $QUIL_CONFIG_FILE
            done
        else
            echo -e "${BLUE}${INFO_ICON} Processing server: $user@$ip (port: $ssh_port)${RESET}"
            add_server_to_config "$ip" "$ssh_port" "$user"
        fi
    else
        echo -e "${RED}${ERROR_ICON} Invalid format for argument: $arg${RESET}"
        echo "Expected format: [user@]<ip>[:<ssh-port>][/worker-count]"
        continue
    fi
done

echo -e "${GREEN}${CHECK_ICON} All provided servers have been processed.${RESET}"
echo -e "${BLUE}${INFO_ICON} Please run 'qtools cluster-setup --master' to configure the newly added servers.${RESET}"
