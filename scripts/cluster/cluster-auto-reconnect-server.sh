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

# Add the server back to servers array
yq eval -i '.service.clustering.servers += ['"$SERVER_TO_MOVE"']' $QTOOLS_CONFIG_FILE

# Remove the server from auto_removed_servers array
yq eval -i '.service.clustering.auto_removed_servers = (.service.clustering.auto_removed_servers | map(select(.ip != "'"$IP_TO_RECONNECT"'")))' $QTOOLS_CONFIG_FILE


echo "Server with IP $IP_TO_RECONNECT has been moved back to active servers."
