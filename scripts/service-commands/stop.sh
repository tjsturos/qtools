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

        qtools update-cron
    else
        echo "Skipping process cleanup in quick mode."
    fi
}

sudo systemctl stop $QUIL_SERVICE_NAME.service

# Check if clustering is enabled
if [ "$IS_CLUSTERING_ENABLED" == "true" ]; then

    if [ "$(is_master)" == "true" ]; then
        echo "Clustering is enabled and this is the main IP. Stopping services on all servers..."
        
        servers=$(get_cluster_ips)
        for ip in $servers; do
            if echo "$(hostname -I)" | grep -q "$ip"; then
                continue
            fi
            echo "Stopping services on $ip"
            ssh -i ~/.ssh/cluster-key "client@$ip" "sudo systemctl stop $QUIL_SERVICE_NAME.service"
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
