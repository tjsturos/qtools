#!/bin/bash
# HELP: Starts the node application service. If .settings.debug is set to true or use --debug flag, this will start node in debug mode.
# PARAM: --debug: will start the node application in debug mode
# Usage: qtools start
# Usage: qtools start --quick
# TODO: qtools start --debug

# get settings
DEBUG_MODE="$(yq '.settings.debug' $QTOOLS_CONFIG_FILE)"


IS_QUICK_MODE=false
# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            DEBUG_MODE="true"
            shift
            ;;
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

enable_peripheral_services() {
    if [ "$IS_QUICK_MODE" == "true" ]; then
        echo "Quick start mode, skipping diagnostics and statistics."
    else
        # Enable diagnostics
        qtools toggle-diagnostics --on

        echo "Diagnostics have been enabled."

        # Enable statistics
        qtools toggle-statistics --on

        echo "Statistics have been enabled."
    fi
}

if [ "$(yq '.service.clustering.enabled // false' $QTOOLS_CONFIG_FILE)" == "false" ]; then
    echo "Starting single node service."
    sudo systemctl start $QUIL_SERVICE_NAME.service
    enable_peripheral_services
else
    # Starting cluster mode for this config
    echo "Starting cluster mode for this config"
    # Check if the current hostname matches the orchestrator hostname
    if is_master; then
        echo "Starting node process on the master node"
        qtools start-cluster --master
        enable_peripheral_services
    else
        qtools start-cluster
    fi
    
fi


