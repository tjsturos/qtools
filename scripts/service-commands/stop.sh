#!/bin/bash
# HELP: Stops the node application service. Will also clean up any leftover node processes (if any).
# Usage: qtools stop
# Usage: qtools stop --quick
# Initialize variables
IS_QUICK_MODE=false
IS_CLUSTERING_ENABLED=$(yq '.service.clustering.enabled // false' $QTOOLS_CONFIG_FILE)
IS_ORCHESTRATOR=false

# Check if this is the orchestrator node
if [ "$(hostname)" == "$(yq '.service.clustering.orchestrator_hostname // ""' $QTOOLS_CONFIG_FILE)" ]; then
    IS_ORCHESTRATOR=true
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --quick)
            IS_QUICK_MODE=true
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
for service in $(systemctl list-units --type=service --state=active | grep "^$QUIL_SERVICE_NAME" | awk '{print $1}'); do
    echo "Stopping service: $service"
    sudo systemctl stop "$service"
done

wait

IS_QUICK_MODE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --quick)
            IS_QUICK_MODE=true
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

IS_CLUSTERING_ENABLED=$(yq '.service.clustering.enabled // false' $QTOOLS_CONFIG_FILE)
IS_ORCHESTRATOR=false

if [ "$(hostname)" == "$(yq '.service.clustering.orchestrator_hostname' $QTOOLS_CONFIG_FILE)" ]; then
    IS_ORCHESTRATOR=true
fi

# Quick mode is essentially no clean up, with intention to immediately restart the node process
if [ "$IS_QUICK_MODE" == "false" ]; then
    # Check if clustering is enabled and if this is the orchestrator node
    if [ "$IS_CLUSTERING_ENABLED" == "true" ] && [ "$IS_ORCHESTRATOR" == "true" ]; then
        # Only stop the node processes on the orchestrator node (they aren't running on non-orchestrator nodes)
        echo "Orchestrator node detected. Disabling peripheral services."
        clean_up_process
    else if [ "$IS_CLUSTERING_ENABLED" == "false" ]; then
        # Always stop the node processes when there is no clustering
        clean_up_process
    fi
fi

# and to make sure any stray node commands are exited
pgrep -f node | grep -v $$ | xargs -r sudo kill -9
