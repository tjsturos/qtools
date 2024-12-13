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

# Add the server to auto_removed_servers array
yq eval -i '.service.clustering.auto_removed_servers += ['"$SERVER_TO_MOVE"']' $QTOOLS_CONFIG_FILE

# Remove the server from the servers array
qtools cluster-remove-server "$IP_TO_REMOVE"

echo "Server with IP $IP_TO_REMOVE has been moved to auto_removed_servers."

