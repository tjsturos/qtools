#!/bin/bash
source $QTOOLS_PATH/scripts/cluster/utils.sh

# Get IP address from first parameter
IP_TO_RECONNECT=$1

if [ -z "$IP_TO_RECONNECT" ]; then
    echo "Error: Please provide the IP address of the server to auto-reconnect."
    exit 1
fi

# Read the current configuration
CONFIG=$(yq eval . $QTOOLS_CONFIG_FILE)

# Get the current auto_removed_servers array
AUTO_REMOVED_SERVERS=$(echo "$CONFIG" | yq eval '.service.clustering.auto_removed_servers' -)

# Find the server entry to be reconnected
SERVER_TO_MOVE=$(echo "$AUTO_REMOVED_SERVERS" | yq eval '.[] | select(.ip == "'"$IP_TO_RECONNECT"'")' -)

if [ -z "$SERVER_TO_MOVE" ]; then
    echo "No server with IP $IP_TO_RECONNECT was found in auto_removed_servers."
    exit 1
fi

# Extract server details
ip=$(echo "$SERVER_TO_MOVE" | yq eval '.ip' -)
ssh_port=$(echo "$SERVER_TO_MOVE" | yq eval '.ssh_port' -)
user=$(echo "$SERVER_TO_MOVE" | yq eval '.user' -)
worker_count=$(echo "$SERVER_TO_MOVE" | yq eval '.data_worker_count' -)
base_port=$(echo "$SERVER_TO_MOVE" | yq eval '.base_port' -)

# Add the server back to servers array
if [ "$worker_count" != "null" ]; then
    yq eval -i ".service.clustering.servers += {\"ip\": \"$ip\", \"ssh_port\": $ssh_port, \"user\": \"$user\", \"data_worker_count\": $worker_count, \"base_port\": $base_port}" "$QTOOLS_CONFIG_FILE"
    echo -e "${GREEN}${CHECK_ICON} Added server $user@$ip:$ssh_port with $worker_count workers to the cluster configuration.${RESET}"
else
    yq eval -i ".service.clustering.servers += {\"ip\": \"$ip\", \"ssh_port\": $ssh_port, \"user\": \"$user\", \"base_port\": $base_port}" "$QTOOLS_CONFIG_FILE"
    echo -e "${GREEN}${CHECK_ICON} Added server $user@$ip:$ssh_port to the cluster configuration.${RESET}"
fi

# Remove the server from auto_removed_servers array
yq eval -i '.service.clustering.auto_removed_servers = (.service.clustering.auto_removed_servers | map(select(.ip != "'"$IP_TO_RECONNECT"'")))' $QTOOLS_CONFIG_FILE


echo "Server with IP $IP_TO_RECONNECT has been moved back to active servers."
