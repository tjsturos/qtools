#! /bin/bash
# This script executes a given command on all remote servers in the cluster

source $QTOOLS_PATH/scripts/cluster/utils.sh

if [ $# -eq 0 ]; then
    echo "Error: No command provided"
    echo "Usage: cluster-remote-command \"<command>\""
    exit 1
fi

COMMAND="$1"

execute_remote_command() {
    local config=$(yq eval . $QTOOLS_CONFIG_FILE)
    local servers=$(echo "$config" | yq eval '.service.clustering.servers' -)
    local server_count=$(echo "$servers" | yq eval '. | length' -)
    
    # Array to store background process PIDs
    declare -a pids

    for ((i=0; i<server_count; i++)); do
        local server=$(echo "$servers" | yq eval ".[$i]" -)
        local server_ip=$(echo "$server" | yq eval '.ip' -)
        local remote_user=$(echo "$server" | yq eval ".user // \"$DEFAULT_USER\"" -)
        local ssh_port=$(echo "$server" | yq eval ".ssh_port // \"$DEFAULT_SSH_PORT\"" -)

        # Skip if it's the current server
        if ! echo "$(hostname -I)" | grep -q "$server_ip"; then
            echo "Starting command execution on $server_ip..."
            (
                ssh_to_remote $server_ip $remote_user $ssh_port "$COMMAND"
                echo "Command completed on $server_ip"
            ) &
            pids+=($!)
        fi
    done

    # Wait for all background processes to complete
    for pid in "${pids[@]}"; do
        wait $pid
    done
    
    echo "All remote commands completed"
}

execute_remote_command
