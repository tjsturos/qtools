#! /bin/bash
# This script checks the memory levels of the slave nodes and restarts the data workers them if they are too low

source $QTOOLS_PATH/scripts/cluster/utils.sh


restart_server_data_workers() {
    local ip=$1
    local remote_user=$2
    local ssh_port=$3
    
    while read -r line; do
        if [[ $line =~ "submitting data proof" ]] || [[ $line =~ "workers not yet available for proving" ]]; then
            echo -e "${GREEN}${CHECK_ICON} Proof submission detected or workers not available, proceeding with restart${RESET}"
            break
        fi
    done < <(journalctl -u $QUIL_SERVICE_NAME -f -n 0)
    ssh_to_remote $ip $remote_user $ssh_port "qtools refresh-data-workers" &
}

check_mem_levels() {
    local config=$(yq eval . $QTOOLS_CONFIG_FILE)
    local servers=$(echo "$config" | yq eval '.service.clustering.servers' -)
    local server_count=$(echo "$servers" | yq eval '. | length' -)
    
    for ((i=0; i<server_count; i++)); do
        local server=$(echo "$servers" | yq eval ".[$i]" -)
        local server_ip=$(echo "$server" | yq eval '.ip' -)
        
        if [ "$server_ip" == "$ip" ]; then
            local remote_user=$(echo "$server" | yq eval ".user // \"$DEFAULT_USER\"" -)
            local ssh_port=$(echo "$server" | yq eval ".ssh_port // \"$DEFAULT_SSH_PORT\"" -)
            if ! echo "$(hostname -I)" | grep -q "$ip"; then
                echo "Running $command on $ip ($remote_user)"

                local mem_usage=$(ssh_to_remote $ip $remote_user $ssh_port "qtools memory-usage")

                if [ "$mem_usage" -gt 90 ]; then
                    echo "Memory usage is too high, restarting data workers for $ip"

                    restart_server_data_workers $ip $remote_user $ssh_port &
                fi
            fi
        fi
    done
}

check_mem_levels