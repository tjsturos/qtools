#!/bin/bash
# HELP: Gets the node application service\'s current status.
# Usage: qtools status

IS_CLUSTERING_ENABLED=$(yq '.service.clustering.enabled // false' $QTOOLS_CONFIG_FILE)

if [ "$IS_CLUSTERING_ENABLED" == "true" ]; then
    # Parse command line arguments
    # Read the config file
    config=$(yq eval . $QTOOLS_CONFIG_FILE)
    
    # Get the array of servers
    servers=$(echo "$config" | yq eval '.service.clustering.servers' -)

    # Get the number of servers
    server_count=$(echo "$servers" | yq eval '. | length' -)

    # Loop through each server
    for ((i=0; i<server_count; i++)); do
        server=$(echo "$servers" | yq eval ".[$i]" -)
        ip=$(echo "$server" | yq eval '.ip' -)

        # Check if the IP is the local machine
        if echo "$(hostname -I)" | grep -q "$ip"; then
            echo "This is the local machine, continuing..."
            sudo systemctl status $QUIL_SERVICE_NAME.service --no-pager
            continue
        fi
        
        # Skip invalid entries
        if [ -z "$ip" ] || [ "$ip" == "null" ]; then
            echo "Skipping invalid server entry: $server"
            continue
        fi

        echo "Checking status of dataworkers on $ip:"
        
        # Use ssh to run the command on the remote machine
        ssh -i ~/.ssh/cluster-key "client@$ip" "sudo systemctl status $QUIL_SERVICE_NAME.service --no-pager"
        echo "----------------------------------------"
    done
else
    sudo systemctl status $QUIL_SERVICE_NAME.service --no-pager
fi
