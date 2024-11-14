#!/bin/bash

DRY_RUN=false
LOCAL_IP=$(get_local_ip)

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --ip)
            IP="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ -z "$IP" ]; then
    echo "Error: --ip parameter is required"
    exit 1
fi

# Get worker count for the IP
WORKER_COUNT=$(get_cluster_worker_count $IP)

update_remote_workers() {
    local ip=$1
    local worker_count=$2

    if [ -z "$worker_count" ] || [ "$worker_count" -lt 1 ]; then
        echo "Error: Could not determine valid worker count for IP $ip"
        exit 1
    fi

    echo "Setting up $worker_count workers on $ip"

    # Stop all existing data worker services
    ssh_command_to_server $ip "sudo systemctl stop dataworker@*.service"

    # Disable the data worker service template
    ssh_command_to_server $ip "sudo systemctl disable dataworker@.service"

    # Enable specific number of worker instances
    ssh_command_to_server $ip "sudo systemctl enable dataworker@{1..$worker_count}.service"

    # Start the worker instances
    ssh_command_to_server $ip "sudo systemctl start dataworker@{1..$worker_count}.service"
}

# Get all servers from config
servers=$(yq eval '.service.clustering.servers' $QTOOLS_CONFIG_FILE)
server_count=$(echo "$servers" | yq eval '. | length' -)

# Loop through each server
for ((i=0; i<server_count; i++)); do
    server=$(echo "$servers" | yq eval ".[$i]" -)
    server_ip=$(echo "$server" | yq eval '.ip' -)
    
    # Skip if IP doesn't match target IP
    if [ "$server_ip" != "$IP" ]; then
        continue
    fi
    
    # Get worker count for this server
    worker_count=$(get_cluster_worker_count $server_ip)
    
    if [ "$DRY_RUN" == "false" ]; then
        if [ "$server_ip" != "$LOCAL_IP" ]; then
            update_remote_workers $server_ip $worker_count
        else
            echo -e "${BLUE}${INFO_ICON} [LOCAL] [ $LOCAL_IP ] Would update $server_ip to run $worker_count workers${RESET}"
            sudo systemctl stop dataworker@*.service
            sudo systemctl disable dataworker@.service
            sudo systemctl enable dataworker@{1..$worker_count}.service
            sudo systemctl start dataworker@{1..$worker_count}.service
        fi
    else
        if [ "$server_ip" != "$LOCAL_IP" ]; then
            echo -e "${BLUE}${INFO_ICON} [DRY RUN] [ $server_ip ] Would update $server_ip to run $worker_count workers${RESET}"
        else
            echo -e "${BLUE}${INFO_ICON} [DRY RUN] [LOCAL] [ $LOCAL_IP ] Would update $server_ip to run $worker_count workers${RESET}"
        fi
    fi
done

update_quil_config $DRY_RUN

