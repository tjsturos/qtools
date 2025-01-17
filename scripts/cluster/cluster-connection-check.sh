#!/bin/bash

source $QTOOLS_PATH/scripts/cluster/utils.sh

# Check for auto-remove flag
AUTO=false
RETRY_INTERVAL=$(yq eval '.scheduled_tasks.cluster.auto_reconnect.interval_seconds // 20' $QTOOLS_CONFIG_FILE)
RETRY_COUNT=$(yq eval '.scheduled_tasks.cluster.auto_reconnect.retry_count // 5' $QTOOLS_CONFIG_FILE)
RECONFIGURE_MASTER=false
DRY_RUN=false

for arg in "$@"; do
    if [ "$arg" = "--auto" ]; then
        AUTO=true
        break
    fi
done


# Function to retry connection with exponential backoff
retry_connection() {
    local ip=$1
    local user=$2
    local ssh_port=$3
    local SERVER_ARRAY_TO_CHECK=$4
    local retry_count=1

    while [ $retry_count -le $RETRY_COUNT ]; do
        echo -e "${YELLOW}${INFO_ICON} Attempt $retry_count of $RETRY_COUNT for $ip${RESET}"
        
        if check_server_ssh_connection "$ip" "$user" "$ssh_port"; then
            echo -e "${GREEN}✓ Successfully connected to $ip on attempt $retry_count${RESET}"
             if [ "$SERVER_ARRAY_TO_CHECK" == "auto_removed_servers" ] && [ "$AUTO" == "true" ]; then
                qtools cluster-auto-reconnect-server "$ip"
                RECONFIGURE_MASTER=true
            fi
            return 0
        fi

        if [ $retry_count -lt $RETRY_COUNT ]; then
            echo -e "${YELLOW}${WARNING_ICON} Connection failed to $ip, waiting $RETRY_INTERVAL seconds before next attempt...${RESET}"
            sleep $RETRY_INTERVAL
        fi
        
        retry_count=$((retry_count + 1))
    done
    if [ "$AUTO" == "true" ] && [ "$SERVER_ARRAY_TO_CHECK" == "servers" ]; then
        echo -e "${YELLOW}${INFO_ICON} Auto-removing server $ip due to failed SSH connection${RESET}"
        qtools cluster-auto-remove-server "$ip"
        RECONFIGURE_MASTER=true
        return 1
    fi
    echo -e "${RED}✗ Failed to connect to $ip after $RETRY_COUNT attempts${RESET}"
    return 1
}


echo -e "${BLUE}${INFO_ICON} Checking SSH connections to all servers...${RESET}"


check_server_array_connections() {
    local SERVER_ARRAY_TO_CHECK=$1
    echo "Checking $SERVER_ARRAY_TO_CHECK..."

    # Get server configurations
    servers=$(yq eval ".service.clustering.$SERVER_ARRAY_TO_CHECK" $QTOOLS_CONFIG_FILE)
    server_count=$(echo "$servers" | yq eval '. | length' -)

    if [ "$server_count" -eq 0 ]; then
        echo -e "${GREEN}✓ No servers found in $SERVER_ARRAY_TO_CHECK${RESET}"
        return 0
    fi
    
    for ((i=0; i<server_count; i++)); do
        local server=$(yq eval ".service.clustering.$SERVER_ARRAY_TO_CHECK[$i]" $QTOOLS_CONFIG_FILE)
        local ip=$(echo "$server" | yq eval '.ip' -)
        local user=$(echo "$server" | yq eval ".user // \"$DEFAULT_USER\"" -)
        local ssh_port=$(echo "$server" | yq eval ".ssh_port // \"$DEFAULT_SSH_PORT\"" -)

        # Skip if this is the local machine
        if echo "$(hostname -I)" | grep -q "$ip"; then
            echo -e "${GREEN}✓ Local server $ip - no SSH check needed${RESET}"
            continue
        fi

        # Check SSH connection
        if check_server_ssh_connection "$ip" "$user" "$ssh_port"; then
            echo -e "${GREEN}✓ Successfully connected to $ip ($user) on port $ssh_port${RESET}"
            if [ "$SERVER_ARRAY_TO_CHECK" == "auto_removed_servers" ] && [ "$AUTO" == "true" ]; then
                qtools cluster-auto-reconnect-server "$ip"
                RECONFIGURE_MASTER=true
            fi
        else
            echo -e "${RED}Failed to connect to $user@$ip:$ssh_port, going to retry...${RESET}"
            retry_connection "$ip" "$user" "$ssh_port" "$SERVER_ARRAY_TO_CHECK" &
        fi
    done
    echo "Done checking $SERVER_ARRAY_TO_CHECK"
}

check_server_array_connections "servers"
check_server_array_connections "auto_removed_servers"

wait

if [ "$RECONFIGURE_MASTER" == "true" ]; then
    echo -e "${YELLOW}Reconfiguring config...${RESET}"
    update_quil_config
    qtools restart --wait
fi
