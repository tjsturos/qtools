#!/bin/bash

DRY_RUN=false
LOCAL_IP=$(get_local_ip)

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
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

update_remote_workers() {
    local ip=$1
    local worker_count=$2

    if [ -z "$worker_count" ] || [ "$worker_count" -lt 1 ]; then
        echo "Error: Could not determine valid worker count for IP $ip"
        exit 1
    fi

    echo -e "${BLUE}${INFO_ICON} [ $ip ] Updating number of workers to $worker_count${RESET}"

    if [ "$DRY_RUN" == "true" ]; then
        return
    fi

    # Stop all existing data worker services
    ssh_command_to_server $ip "sudo systemctl stop dataworker@*.service"

    # Disable the data worker service template
    ssh_command_to_server $ip "sudo systemctl disable dataworker@.service"

    # Enable specific number of worker instances
    ssh_command_to_server $ip "sudo systemctl enable dataworker@{1..$worker_count}.service"

    # Start the worker instances
    ssh_command_to_server $ip "sudo systemctl start dataworker@{1..$worker_count}.service"
}

update_local_workers() {
    local worker_count=$1

    echo -e "${BLUE}${INFO_ICON} [LOCAL] Updating number of workers to $worker_count${RESET}"

    if [ "$DRY_RUN" == "true" ]; then
        return
    fi

    sudo systemctl stop dataworker@*.service
    sudo systemctl disable dataworker@.service
    sudo systemctl enable dataworker@{1..$worker_count}.service
    sudo systemctl start dataworker@{1..$worker_count}.service
}


update_workers() {
    # Get all servers from config
    servers=$(yq eval '.service.clustering.servers' $QTOOLS_CONFIG_FILE)
    server_count=$(echo "$servers" | yq eval '. | length' -)

    # Loop through each server
    for ((i=0; i<server_count; i++)); do
        server=$(echo "$servers" | yq eval ".[$i]" -)
        server_ip=$(echo "$server" | yq eval '.ip' -)
        worker_count=$(echo "$server" | yq eval '.data_worker_count' -)
      
        if [ "$DRY_RUN" == "false" ]; then
            if [ "$server_ip" != "$LOCAL_IP" ]; then
                update_remote_workers $server_ip $worker_count
            else
                update_local_workers $worker_count
            fi
        fi
    done
}

verify_changes() {
    # Verify worker counts match expected values
    RESTART_MASTER=true
    for ((i=0; i<server_count; i++)); do
        server=$(echo "$servers" | yq eval ".[$i]" -)
        server_ip=$(echo "$server" | yq eval '.ip' -)
        
        # Get expected worker count
        expected_count=$(get_cluster_worker_count $server_ip)

        if [ "$DRY_RUN" == "false" ]; then
            if [ "$server_ip" != "$LOCAL_IP" ]; then
                # Get actual worker count from remote server
                actual_count=$(ssh_command_to_server $server_ip "systemctl list-units --type=service --status=running | grep dataworker | wc -l")
                echo "Server $server_ip: Expected $expected_count workers, found $actual_count running"
                
                if [ "$actual_count" != "$expected_count" ]; then
                    echo -e "${RED}${WARNING_ICON} Warning: Worker count mismatch on $server_ip${RESET}"
                    echo -e "${RED}${WARNING_ICON} Expected: $expected_count, Actual: $actual_count${RESET}"
                    RESTART_MASTER=false
                else
                    echo -e "${GREEN}${CHECK_ICON} Worker count verified on $server_ip${RESET}"
                fi
            else
                # Get actual worker count on local machine
                actual_count=$(systemctl list-units --type=service | grep dataworker | wc -l)
                echo "Local server: Expected $expected_count workers, found $actual_count running"
                
                if [ "$actual_count" != "$expected_count" ]; then
                    echo -e "${RED}${WARNING_ICON} Warning: Local worker count mismatch${RESET}"
                    echo -e "${RED}${WARNING_ICON} Expected: $expected_count, Actual: $actual_count${RESET}"
                    RESTART_MASTER=false
                else
                    echo -e "${GREEN}${CHECK_ICON} Local worker count verified${RESET}"
                fi
            fi
        else
            echo -e "${BLUE}${INFO_ICON} [DRY RUN] Would verify worker count on $server_ip matches $expected_count${RESET}"
        fi
    done
    echo "$RESTART_MASTER"
}

update_workers

update_quil_config $DRY_RUN

wait 

if [ "$(verify_changes)" == "true" ] && [ "$DRY_RUN" == "false" ]; then
    qtools restart
fi


