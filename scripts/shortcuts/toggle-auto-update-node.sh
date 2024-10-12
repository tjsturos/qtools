#!/bin/bash
# HELP: Toggles auto-updates on or off in the qtools configuration.
# PARAM: --on: Explicitly turn auto-updates on
# PARAM: --off: Explicitly turn auto-updates off
# Usage: qtools toggle-auto-update [--on|--off]

# Function to set auto-update status
set_auto_update_status() {
    local status=$1
    yq -i ".scheduled_tasks.updates.node.enabled = $status" $QTOOLS_CONFIG_FILE
    echo "Auto-updates have been turned $([[ $status == true ]] && echo "on" || echo "off")."
    qtools update-cron
}

# Check current auto-update status
current_status=$(yq '.scheduled_tasks.updates.node.enabled // "false"' $QTOOLS_CONFIG_FILE)

# Parse command line arguments
if [[ $# -eq 1 ]]; then
    case $1 in
        --on)
            if [ "$current_status" == "true" ]; then
                echo "Node auto-updates are already enabled."
                exit 0
            fi
            set_auto_update_status true
            exit 0
            ;;
        --off)
            if [ "$current_status" == "false" ]; then
                echo "Node auto-updates are already disabled."
                exit 0
            fi
            set_auto_update_status false
            exit 0
            ;;
        *)
            echo "Invalid argument. Use --on or --off to explicitly set auto-update status."
            exit 1
            ;;
    esac
fi

# If no arguments provided, toggle the current status
if [[ $current_status == "true" ]]; then
    set_auto_update_status false
else
    set_auto_update_status true
fi

