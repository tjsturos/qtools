#!/bin/bash

source $QTOOLS_PATH/scripts/cluster/utils.sh

echo -e "${BLUE}${INFO_ICON} Checking data worker ports on all servers...${RESET}"

# Get server configuration
servers=$(yq eval '.service.clustering.servers' $QTOOLS_CONFIG_FILE)
server_count=$(echo "$servers" | yq eval '. | length' -)
base_port=$(yq eval '.service.clustering.base_port // "40000"' $QTOOLS_CONFIG_FILE)

# Check each server
for ((i=0; i<server_count; i++)); do
    server=$(yq eval ".service.clustering.servers[$i]" $QTOOLS_CONFIG_FILE)
    ip=$(echo "$server" | yq eval '.ip' -)
    user=$(echo "$server" | yq eval ".user // \"$DEFAULT_USER\"" -)
    ssh_port=$(echo "$server" | yq eval ".ssh_port // \"$DEFAULT_SSH_PORT\"" -)
    data_worker_count=$(echo "$server" | yq eval '.data_worker_count // "0"' -)

    if [ -z "$ip" ] || [ "$ip" == "null" ]; then
        echo -e "${RED}✗ Failed to get IP for server $i${RESET}"
        continue
    fi

    if [ "$data_worker_count" -gt 0 ]; then
        check_data_worker_services "$ip" "$user" "$ssh_port" "$data_worker_count" "$base_port"
    else
        echo -e "${BLUE}${INFO_ICON} Server $ip has no configured data workers${RESET}"
    fi
done
