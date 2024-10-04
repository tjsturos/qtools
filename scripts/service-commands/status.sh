#!/bin/bash
# HELP: Gets the node application service\'s current status.
# Usage: qtools status

IS_CLUSTERING_ENABLED=$(yq '.service.clustering.enabled // false' $QTOOLS_CONFIG_FILE)

if [ "$IS_CLUSTERING_ENABLED" == "true" ]; then
    

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --core)
                if [[ -n $2 && $2 =~ ^[0-9]+$ ]]; then
                    CORE_ID=$2
                    echo "Status for data worker core $CORE_ID:"
                    sudo systemctl status $QUIL_SERVICE_NAME-dataworker@$CORE_ID.service --no-pager
                    echo ""
                    shift 2
                else
                    echo "Error: --core option requires a valid numeric core ID"
                    exit 1
                fi
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
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
        ssh -i ~/.ssh/cluster-key "$ip" "
            # Get the count of active (non-dead) dataworker services
            active_count=\$(systemctl list-units --type=service --state=active,running | grep '$QUIL_SERVICE_NAME-dataworker@' | wc -l)
            
            echo \"Number of active $QUIL_SERVICE_NAME dataworker services: \$active_count\"
        "
        echo "----------------------------------------"
    done
else
    sudo systemctl status $QUIL_SERVICE_NAME.service --no-pager
fi
