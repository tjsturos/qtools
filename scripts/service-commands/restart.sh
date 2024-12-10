#!/bin/bash

# HELP: Stops and then starts the node application service, effectively a restart.
# Usage: qtools restart

WAIT=false
# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --on-next-proof|--wait|on-next-submission|-w|-np)
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
    sudo systemctl restart $QUIL_SERVICE_NAME
else
    sudo systemctl restart $QUIL_SERVICE_NAME
fi