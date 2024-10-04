#!/bin/bash
# HELP: Stops the node application service. Will also clean up any leftover node processes (if any).
# Usage: qtools stop
# Usage: qtools stop --quick
# Initialize variables
IS_QUICK_MODE=false
IS_CLUSTERING_ENABLED=$(yq '.service.clustering.enabled // false' $QTOOLS_CONFIG_FILE)
IS_KILL_MODE=false
# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --quick)
            IS_QUICK_MODE=true
            shift
            ;;
        --kill)
            IS_KILL_MODE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ "$IS_QUICK_MODE" == "true" ]; then
    echo "Quick stop mode, skipping peripheral service disabling."
fi

# Function to clean up processes
clean_up_process() {
    if [ "$IS_QUICK_MODE" != "true" ]; then
        # Backup store
        qtools backup-store

        # Disable backups
        qtools toggle-backups --off
        
        # Disable diagnostics
        qtools toggle-diagnostics --off

        # Disable statistics
        qtools toggle-statistics --off
    else
        echo "Skipping process cleanup in quick mode."
    fi
}

# Stop all services that start with $QUIL_SERVICE_NAME
# Get all active services that start with $QUIL_SERVICE_NAME
active_services=$(systemctl list-units --type=service --state=active | grep "$QUIL_SERVICE_NAME" | awk '{print $1}')

# Check if there are any active services
if [ -z "$active_services" ]; then
    echo "No active services found starting with $QUIL_SERVICE_NAME"
else
    # Stop each active service
    for service in $active_services; do
        echo "Stopping service: $service"
        sudo systemctl stop "$service"
        
        # Check if the service was successfully stopped
        if ! systemctl is-active --quiet "$service"; then
            echo "Service $service stopped successfully"
        else
            echo "Failed to stop service: $service"
        fi
    done
fi

stop_core() {
    local CORE_ID=$1
    echo "Stopping core $CORE_ID"
    sudo systemctl stop $QUIL_SERVICE_NAME-dataworker@$CORE_ID.service
}

if [ "$IS_CLUSTERING_ENABLED" == "true" ]; then
    echo "Stopping core processes on local machine"
    core_index=1
    local_core_count=$(($(nproc)))
    if [ "$(is_master)" == "true" ]; then
        local_core_count=$(($local_core_count - 1))
    fi

    for ((i=0; i<$local_core_count; i++)); do
        stop_core $(($i + $core_index)) &
        core_index=$(($core_index + 1))
    done
fi

# Check if clustering is enabled
if [ "$IS_CLUSTERING_ENABLED" == "true" ]; then

    if [ "$(is_master)" == "true" ]; then
        echo "Clustering is enabled and this is the main IP. Stopping services on all servers..."
        
        # Get the list of servers
        servers=$(yq eval '.service.clustering.servers' $QTOOLS_CONFIG_FILE)
        server_count=$(echo "$servers" | yq eval '. | length' -)


        MAIN_IP=$(yq '.service.clustering.main_ip' $QTOOLS_CONFIG_FILE)
        # Loop through each server
        for ((i=0; i<server_count; i++)); do
            server=$(yq eval ".service.clustering.servers[$i]" $QTOOLS_CONFIG_FILE)
        
            ip=$(echo "$server" | yq eval '.ip' -)

            if [ "$ip" == "$MAIN_IP" ]; then
            continue
            fi
            echo "Stopping services on $ip"
            
            # Run the qtools stop command on the remote server
            # Note: This assumes SSH key-based authentication is set up
            ssh -i ~/.ssh/cluster-key $ip "qtools stop"
            
            if [ $? -eq 0 ]; then
                echo "Successfully stopped services on $ip"
            else
                echo "Failed to stop services on $ip"
            fi
        done
    else
        echo "Not the master node, nothing to do further."
    fi
else
    echo "Clustering is not enabled. Skipping remote server operations."
fi


clean_up_process() {
    # and to make sure any stray node commands are exited
    # Backup store
    qtools backup-store

    # Disable backups so any changes to store from this point are not saved to remote storage
    qtools toggle-backups --off
    
    # Disable diagnostics as there will not be any fixes to be made while not running
    qtools toggle-diagnostics --off

    # Disable statistics as no updated statistics can be collected while not running
    qtools toggle-statistics --off
}


# Quick mode is essentially no clean up, with intention to immediately restart the node process
if [ "$IS_QUICK_MODE" == "false" ]; then
    # Check if clustering is enabled and if this is the orchestrator node
    if [ "$IS_CLUSTERING_ENABLED" == "true" ] && [ "$(is_master)" == "true" ]; then
        # Only stop the node processes on the master node (they aren't running on non-orchestrator nodes)
       
        clean_up_process
    elif [ "$IS_CLUSTERING_ENABLED" == "false" ]; then
        # Always stop the node processes when there is no clustering
        clean_up_process
    fi
fi

# Kill mode is essentially quick mode + kill the node process
if [ "$IS_KILL_MODE" == "true" ]; then
    echo "Kill mode, killing node process"
    pgrep -f node | grep -v $$ | xargs -r sudo kill -9
fi
