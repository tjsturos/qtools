#! /bin/bash
# This script checks the memory levels of the slave nodes and restarts the data workers them if they are too low

source $QTOOLS_PATH/scripts/cluster/utils.sh

THRESHOLD=$(yq eval '.scheduled_tasks.cluster.memory_check.threshold // 90' $QTOOLS_CONFIG_FILE)
RESTART_MASTER=$(yq eval '.scheduled_tasks.cluster.memory_check.restart_master // false' $QTOOLS_CONFIG_FILE)
SERVERS_RESTARTED=()

restart_server_data_workers() {
    local ip=$1
    local remote_user=$2
    local ssh_port=$3
    SERVERS_RESTARTED+=($ip)
    echo "Waiting for proof submission or workers not available to restart data workers for $ip"
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
        local remote_user=$(echo "$server" | yq eval ".user // \"$DEFAULT_USER\"" -)
        local ssh_port=$(echo "$server" | yq eval ".ssh_port // \"$DEFAULT_SSH_PORT\"" -)

        if ! echo "$(hostname -I)" | grep -q "$server_ip"; then
            echo "Running 'qtools memory-usage' on $server_ip ($remote_user)"

            local mem_usage=$(ssh_to_remote $server_ip $remote_user $ssh_port "qtools memory-usage")
            echo "Memory usage for $server_ip: $mem_usage%"
            if [ "$mem_usage" -gt $THRESHOLD ]; then
                echo "Memory usage is too high, restarting data workers for $server_ip"

                restart_server_data_workers $server_ip $remote_user $ssh_port &
            else
                echo "Memory usage is too low (< $THRESHOLD%), skipping restart for $server_ip"
            fi
        fi
    done
}

check_mem_levels

if [ ${#SERVERS_RESTARTED[@]} -gt 0 ]; then
    echo "Restarted ${#SERVERS_RESTARTED[@]} servers: ${SERVERS_RESTARTED[@]}"
    if [ "$RESTART_MASTER" == "true" ] && [ "$(is_master)" == "true" ]; then
        echo "Restarting master node"
        sudo systemctl restart $MASTER_SERVICE_NAME
    fi
    
else
    echo "No servers restarted"
fi
