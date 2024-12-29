#!/bin/bash
# HELP: Stops the node application service. Will also clean up any leftover node processes (if any).
# Usage: qtools stop
# Usage: qtools stop --quick
# Initialize variables
IS_CLUSTERING_ENABLED=$(yq '.service.clustering.enabled // false' $QTOOLS_CONFIG_FILE)
IS_KILL_MODE=false
CORE_INDEX=false
WAIT=false
# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --kill)
            IS_KILL_MODE=true
            shift
            ;;
        --core-index)
            CORE_INDEX=$2
            shift
            shift
            ;;
        --wait)
            WAIT=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done


if [ "$WAIT" == "true" ]; then
    echo -e "${BLUE}${INFO_ICON} Waiting for next proof submission or workers to be available...${RESET}"
    while read -r line; do
        if [[ $line =~ "submitting data proof" ]] || [[ $line =~ "workers not yet available for proving" ]]; then
            echo -e "${GREEN}${CHECK_ICON} Proof submission detected or workers not available, proceeding with restart${RESET}"
            break
        fi
    done < <(journalctl -u $QUIL_SERVICE_NAME -f -n 0)

    sudo systemctl stop $QUIL_SERVICE_NAME.service
 
else
    sudo systemctl stop $QUIL_SERVICE_NAME.service
fi


# Check if clustering is enabled
if [ "$IS_CLUSTERING_ENABLED" == "true" ]; then
    qtools cluster-stop
fi

# Kill mode is essentially quick mode + kill the node process
if [ "$IS_KILL_MODE" == "true" ]; then
    echo "Kill mode, killing node process"
    pgrep -f node | grep -v $$ | xargs -r sudo kill -9
fi
