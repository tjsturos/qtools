#!/bin/bash
# HELP: Stops the node application service. Will also clean up any leftover node processes (if any).
# Usage: qtools stop
# Usage: qtools stop --quick
# Initialize variables
IS_QUICK_MODE=false
IS_CLUSTERING_ENABLED=$(yq '.service.clustering.enabled // false' $QTOOLS_CONFIG_FILE)
IS_KILL_MODE=false
CORE_INDEX=false
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
        --core-index)
            CORE_INDEX=$2
            shift
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

sudo systemctl stop $QUIL_SERVICE_NAME.service

# Check if clustering is enabled
if [ "$IS_CLUSTERING_ENABLED" == "true" ]; then

    if [ "$(is_master)" == "true" ]; then
        echo "Clustering is enabled and this is the main IP. Stopping services on all servers..."
        
        # Get the list of servers
        servers=$(yq eval '.service.clustering.servers' $QTOOLS_CONFIG_FILE)
        server_count=$(echo "$servers" | yq eval '. | length' -)
        
        MAIN_IP=$(yq '.service.clustering.main_ip' $QTOOLS_CONFIG_FILE)
       
        # Loop through each server
        for ((i=0; i<$server_count; i++)); do
            server=$(yq eval ".service.clustering.servers[$i]" $QTOOLS_CONFIG_FILE)
        
            ip=$(echo "$server" | yq eval '.ip' -)

            if [ "$ip" == "$MAIN_IP" ]; then
                continue
            fi
            echo "Stopping services on $ip"

            if [ "$(is_master)" != "true" ]; then
                 # Run the qtools stop command on the remote server
                # Note: This assumes SSH key-based authentication is set up
                ssh -i ~/.ssh/cluster-key client@$ip "qtools stop"
                if [ $? -eq 0 ]; then
                    echo "Successfully stopped services on $ip"
                else
                    echo "Failed to stop services on $ip"
                fi
            fi
        done
    fi
fi

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
