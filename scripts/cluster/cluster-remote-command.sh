#! /bin/bash
# This script executes a given command on all remote servers in the cluster

source $QTOOLS_PATH/scripts/cluster/utils.sh

# Parse command line arguments
TARGET_SERVERS=""
COMMAND=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --server)
            TARGET_SERVERS="$2"
            shift 2
            ;;
        --servers)
            TARGET_SERVERS="$2"
            shift 2
            ;;
        *)
            if [ -z "$COMMAND" ]; then
                COMMAND="$1"
            else
                COMMAND="$COMMAND $1"
            fi
            shift
            ;;
    esac
done

if [ -z "$COMMAND" ]; then
    echo "Error: No command provided"
    echo "Usage: cluster-remote-command [--server <ip4>] [--servers \"<ip4>|<ip4>\"] \"<command>\""
    exit 1
fi

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
        if echo "$(hostname -I)" | grep -q "$server_ip"; then
            continue
        fi

        # Skip if target servers are specified and this server is not in the list
        if [ -n "$TARGET_SERVERS" ]; then
            if ! echo "$TARGET_SERVERS" | grep -q "$server_ip"; then
                continue
            fi
        fi

        echo "Starting command execution on $server_ip..."
        (
            ssh_to_remote $server_ip $remote_user $ssh_port "$COMMAND"
            echo "Command completed on $server_ip"
        ) &
        pids+=($!)
    done

    # Wait for all background processes to complete
    for pid in "${pids[@]}"; do
        wait $pid
    done
    
    echo "All remote commands completed"
}

execute_remote_command
