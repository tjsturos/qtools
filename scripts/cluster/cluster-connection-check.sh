#!/bin/bash

# Get server configurations
servers=$(yq eval '.service.clustering.servers' $QTOOLS_CONFIG_FILE)
server_count=$(echo "$servers" | yq eval '. | length' -)

if [ "$server_count" -eq 0 ]; then
    echo -e "${RED}${WARNING_ICON} No servers configured in $QTOOLS_CONFIG_FILE${RESET}"
    echo -e "${BLUE}${INFO_ICON} Please add server configurations to the clustering section before running this script${RESET}"
    exit 1
fi

echo -e "${BLUE}${INFO_ICON} Checking SSH connections to all servers...${RESET}"

# Loop through each server
for ((i=0; i<server_count; i++)); do
    server=$(yq eval ".service.clustering.servers[$i]" $QTOOLS_CONFIG_FILE)
    ip=$(echo "$server" | yq eval '.ip' -)
    user=$(echo "$server" | yq eval ".user // \"$DEFAULT_USER\"" -)
    ssh_port=$(echo "$server" | yq eval ".ssh_port // \"$DEFAULT_SSH_PORT\"" -)

    # Skip if this is the local machine
    if echo "$(hostname -I)" | grep -q "$ip"; then
        echo -e "${GREEN}✓ Local server $ip - no SSH check needed${RESET}"
        continue
    fi

    # Check SSH connection
    if check_server_ssh_connection "$ip" "$user" "$ssh_port"; then
        echo -e "${GREEN}✓ Successfully connected to $ip ($user) on port $ssh_port${RESET}"
    else
        echo -e "${RED}✗ Failed to connect to $ip ($user) on port $ssh_port${RESET}"
        echo -e "${BLUE}${INFO_ICON} Please verify:"
        echo "  - SSH key exists at $SSH_CLUSTER_KEY"
        echo "  - Public key is in authorized_keys on remote server"
        echo "  - Remote server is running and accessible"
        echo "  - SSH port $ssh_port is open${RESET}"
    fi
done
