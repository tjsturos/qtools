#!/bin/bash

# Function to add a server to the cluster configuration
add_server_to_config() {
    local ip=$1
    local ssh_port=${2:-$DEFAULT_SSH_PORT}  # Default SSH port is 22 if not specified
    local user=${3:-$DEFAULT_USER}   # Default user is the current user if not specified
    local worker_count=${4:-null}

    # Check if the server already exists in the config
    if yq eval ".service.clustering.servers[] | select(.ip == \"$ip\")" "$QTOOLS_CONFIG_FILE" | grep -q .; then
        echo -e "${YELLOW}${WARNING_ICON} Server $ip already exists in the configuration. Skipping.${RESET}"
        return
    fi

    # Add the new server to the configuration
    if [ "$worker_count" != "null" ]; then
        yq eval -i ".service.clustering.servers += {\"ip\": \"$ip\", \"ssh_port\": $ssh_port, \"user\": \"$user\", \"data_worker_count\": $worker_count}" "$QTOOLS_CONFIG_FILE"
    else
        yq eval -i ".service.clustering.servers += {\"ip\": \"$ip\", \"ssh_port\": $ssh_port, \"user\": \"$user\"}" "$QTOOLS_CONFIG_FILE"
    fi
    echo -e "${GREEN}${CHECK_ICON} Added server $ip to the cluster configuration.${RESET}"
}

# Main script execution
if [ $# -eq 0 ]; then
    echo -e "${RED}${ERROR_ICON} Error: No IP addresses provided.${RESET}"
    echo "Usage: $0 <ip1> [ip2] [ip3] ..."
    exit 1
fi

# Loop through all provided IP addresses
for arg in "$@"; do
    # Check if argument contains a colon
    if [[ $arg == *:* ]]; then
        # Split on colon - IP is before, worker count after
        ip=${arg%:*}
        worker_count=${arg#*:}
        echo -e "${BLUE}${INFO_ICON} Processing server: $ip (workers: $worker_count)${RESET}"
        add_server_to_config "$ip" "$DEFAULT_SSH_PORT" "$DEFAULT_USER" "$worker_count"
    else
        # No colon - treat entire arg as IP
        ip=$arg
        echo -e "${BLUE}${INFO_ICON} Processing server: $ip${RESET}"
        add_server_to_config "$ip"
    fi
done

echo -e "${GREEN}${CHECK_ICON} All provided servers have been processed.${RESET}"
echo -e "${BLUE}${INFO_ICON} Please run 'qtools cluster-setup --master' to configure the newly added servers.${RESET}"
