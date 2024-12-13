#!/bin/bash
source $QTOOLS_PATH/scripts/cluster/utils.sh

# Get IP address from first parameter
IP_TO_REMOVE=$1

if [ -z "$IP_TO_REMOVE" ]; then
    echo "Error: Please provide the IP address of the server to auto-remove."
    exit 1
fi

# Read the current configuration
CONFIG=$(yq eval . $QTOOLS_CONFIG_FILE)

# Get the current servers array
SERVERS=$(echo "$CONFIG" | yq eval '.service.clustering.servers' -)

# Find the server entry to be removed
SERVER_TO_MOVE=$(echo "$SERVERS" | yq eval '.[] | select(.ip == "'"$IP_TO_REMOVE"'")' -)

if [ -z "$SERVER_TO_MOVE" ]; then
    echo "No server with IP $IP_TO_REMOVE was found in the configuration."
    exit 1
fi

# Extract server details
ip=$(echo "$SERVER_TO_MOVE" | yq eval '.ip' -)
ssh_port=$(echo "$SERVER_TO_MOVE" | yq eval '.ssh_port' -)
user=$(echo "$SERVER_TO_MOVE" | yq eval '.user' -)
worker_count=$(echo "$SERVER_TO_MOVE" | yq eval '.data_worker_count' -)
base_port=$(echo "$SERVER_TO_MOVE" | yq eval '.base_port' -)

# Add the server to auto_removed_servers array
if [ "$worker_count" != "null" ]; then
    yq eval -i '.service.clustering.auto_removed_servers += {"ip": "'"$ip"'", "ssh_port": '"$ssh_port"', "user": "'"$user"'", "data_worker_count": '"$worker_count"', "base_port": '"$base_port"'}' "$QTOOLS_CONFIG_FILE"
else
    yq eval -i '.service.clustering.auto_removed_servers += {"ip": "'"$ip"'", "ssh_port": '"$ssh_port"', "user": "'"$user"'", "base_port": '"$base_port"'}' "$QTOOLS_CONFIG_FILE"
fi

# Remove the server from servers array
yq eval -i '.service.clustering.servers = (.service.clustering.servers | map(select(.ip != "'"$IP_TO_REMOVE"'")))' $QTOOLS_CONFIG_FILE

echo "Server with IP $IP_TO_REMOVE has been moved to auto_removed_servers."

