#!/bin/bash
source $QTOOLS_PATH/scripts/cluster/utils.sh

# Check if an IP address was provided
if [ $# -eq 0 ]; then
    echo "Error: Please provide the IP address of the server to remove."
    exit 1
fi

IP_TO_REMOVE=$1

# Read the current configuration
CONFIG=$(yq eval . $QTOOLS_CONFIG_FILE)

# Get the current servers array
SERVERS=$(echo "$CONFIG" | yq eval '.service.clustering.servers' -)

# Filter out the server with the given IP
NEW_SERVERS=$(echo "$SERVERS" | yq eval 'map(select(.ip != '""""$IP_TO_REMOVE""""'))' -)

# Update the configuration file
yq eval -i '.service.clustering.servers = '"$NEW_SERVERS"'' $QTOOLS_CONFIG_FILE

# 2.1+: No longer maintaining engine.dataWorkerMultiaddrs entries

# Check if the server was actually removed
if [ "$(echo "$NEW_SERVERS" | yq eval '. | length' -)" -lt "$(echo "$SERVERS" | yq eval '. | length' -)" ]; then
    echo "Server with IP $IP_TO_REMOVE has been removed from the configuration."
else
    echo "No server with IP $IP_TO_REMOVE was found in the configuration."
fi

# If this is the master node, update the configuration on all remaining servers
if [ "$(is_master)" == "true" ]; then
    echo "Updating configuration on remaining servers..."
    qtools restart --wait
fi
