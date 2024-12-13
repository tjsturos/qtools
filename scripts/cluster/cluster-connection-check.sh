#!/bin/bash

source $QTOOLS_PATH/scripts/cluster/utils.sh

# Check for auto-remove flag
AUTO_REMOVE=false
SERVERS="servers"
for arg in "$@"; do
    if [ "$arg" = "--auto-remove" ]; then
        AUTO_REMOVE=true
        break
    fi
    if [ "$arg" = "--auto-removed-servers" ]; then
        SERVERS="auto_removed_servers"
        break
    fi
done


# Get server configurations
servers=$(yq eval ".service.clustering.$SERVERS" $QTOOLS_CONFIG_FILE)
server_count=$(echo "$servers" | yq eval '. | length' -)

if [ "$server_count" -eq 0 ]; then
    echo -e "${GREEN}✓ No servers found in $SERVERS${RESET}"
    exit 0
fi

RETRY_INTERVAL=$(yq eval '.scheduled_tasks.cluster.auto_reconnect.interval_seconds // 20' $QTOOLS_CONFIG_FILE)
RETRY_COUNT=$(yq eval '.scheduled_tasks.cluster.auto_reconnect.retry_count // 5' $QTOOLS_CONFIG_FILE)

# Function to retry connection with exponential backoff
retry_connection() {
    local ip=$1
    local user=$2
    local ssh_port=$3
    local retry_count=1

    while [ $retry_count -le $RETRY_COUNT ]; do
        echo -e "${YELLOW}${INFO_ICON} Attempt $retry_count of $RETRY_COUNT for $ip${RESET}"
        
        if check_server_ssh_connection "$ip" "$user" "$ssh_port"; then
            echo -e "${GREEN}✓ Successfully connected to $ip on attempt $retry_count${RESET}"
            return 0
        fi

        if [ $retry_count -lt $RETRY_COUNT ]; then
            echo -e "${YELLOW}${WARNING_ICON} Connection failed, waiting $RETRY_INTERVAL seconds before next attempt...${RESET}"
            sleep $RETRY_INTERVAL
        fi
        
        retry_count=$((retry_count + 1))
    done
    if [ "$AUTO_REMOVE" != "true" ]; then
        echo -e "${YELLOW}${INFO_ICON} Auto-removing server $ip due to failed SSH connection${RESET}"
        qtools cluster-auto-remove-server "$ip"
        return 1
    fi
    echo -e "${RED}✗ Failed to connect to $ip after $RETRY_COUNT attempts${RESET}"
    return 1
}


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
        if [ "$SERVERS" == "auto_removed_servers" ]; then
            qtools cluster-auto-reconnect-server "$ip"
        fi
    else
        retry_connection "$ip" "$user" "$ssh_port" &
    fi
done
