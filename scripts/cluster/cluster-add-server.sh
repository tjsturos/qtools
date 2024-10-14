#!/bin/bash

# Function to add a server to the cluster configuration
add_server_to_config() {
    local ip=$1
    local ssh_port=${2:-22}  # Default SSH port is 22 if not specified
    local user=${3:-$USER}   # Default user is the current user if not specified

    # Check if the server already exists in the config
    if yq eval ".service.clustering.servers[] | select(.ip == \"$ip\")" "$QTOOLS_CONFIG_FILE" | grep -q .; then
        echo -e "${YELLOW}${WARNING_ICON} Server $ip already exists in the configuration. Skipping.${RESET}"
        return
    fi

    # Add the new server to the configuration
    yq eval -i ".service.clustering.servers += {\"ip\": \"$ip\", \"ssh_port\": $ssh_port, \"user\": \"$user\"}" "$QTOOLS_CONFIG_FILE"
    echo -e "${GREEN}${SUCCESS_ICON} Added server $ip to the cluster configuration.${RESET}"
}

# Main script execution
if [ $# -eq 0 ]; then
    echo -e "${RED}${ERROR_ICON} Error: No IP addresses provided.${RESET}"
    echo "Usage: $0 <ip1> [ip2] [ip3] ..."
    exit 1
fi

# Loop through all provided IP addresses
for ip in "$@"; do
    echo -e "${BLUE}${INFO_ICON} Processing server: $ip${RESET}"
    add_server_to_config "$ip"
done

echo -e "${GREEN}${SUCCESS_ICON} All provided servers have been processed.${RESET}"
echo -e "${BLUE}${INFO_ICON} Please run 'qtools setup-cluster' to configure the newly added servers.${RESET}"
