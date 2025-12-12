#!/bin/bash
# HELP: Toggles direct peers updates on or off in the qtools configuration.
# PARAM: --on: Explicitly turn direct peers updates on
# PARAM: --off: Explicitly turn direct peers updates off
# Usage: qtools toggle-direct-peers [--on|--off]

# Function to set direct peers update status
set_direct_peers_status() {
    local status=$1
    yq -i ".scheduled_tasks.direct_peers.enabled = $status" $QTOOLS_CONFIG_FILE
    echo "Direct peers updates have been turned $([[ $status == true ]] && echo "on" || echo "off")."
    qtools --describe "toggle-direct-peers" update-cron
}

# Check current direct peers update status
current_status=$(yq '.scheduled_tasks.direct_peers.enabled // false' $QTOOLS_CONFIG_FILE)

# Parse command line arguments
if [[ $# -eq 1 ]]; then
    case $1 in
        --on)
            if [ "$current_status" == "true" ]; then
                echo "Direct peers updates are already enabled."
                exit 0
            fi
            set_direct_peers_status true
            exit 0
            ;;
        --off)
            if [ "$current_status" == "false" ]; then
                echo "Direct peers updates are already disabled."
                exit 0
            fi
            set_direct_peers_status false
            exit 0
            ;;
        *)
            echo "Invalid argument. Use --on or --off to explicitly set direct peers update status."
            exit 1
            ;;
    esac
fi

# If no arguments provided, toggle the current status
if [[ $current_status == "true" ]]; then
    set_direct_peers_status false
else
    set_direct_peers_status true
fi