#!/bin/bash
# HELP: Gets the node application service\'s current status.
# Usage: qtools status

IS_CLUSTERING_ENABLED=$(yq '.service.clustering.enabled // false' $QTOOLS_CONFIG_FILE)

if [ "$IS_CLUSTERING_ENABLED" == "true" ]; then

    if [ "$(is_master)" == "true" ]; then
        servers=$(get_cluster_ips)
   
        # Loop through each server
        for ip in $servers; do
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
else
    sudo systemctl status $QUIL_SERVICE_NAME.service --no-pager
fi
