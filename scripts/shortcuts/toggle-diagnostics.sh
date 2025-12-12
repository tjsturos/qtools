#!/bin/bash
# HELP: Toggles diagnostics on or off in the qtools configuration.
# PARAM: --on: Explicitly turn diagnostics on
# PARAM: --off: Explicitly turn diagnostics off
# Usage: qtools toggle-diagnostics [--on|--off]

# Function to set diagnostics status
set_diagnostics_status() {
    local status=$1
    yq -i ".scheduled_tasks.diagnostics.enabled = $status" $QTOOLS_CONFIG_FILE
    echo "Diagnostics have been turned $([[ $status == true ]] && echo "on" || echo "off")."
    qtools --describe "toggle-diagnostics" update-cron
}

# Check current diagnostics status
current_status=$(yq '.scheduled_tasks.diagnostics.enabled // false' $QTOOLS_CONFIG_FILE)

# Parse command line arguments
if [[ $# -eq 1 ]]; then
    case $1 in
        --on)
            set_diagnostics_status true
            exit 0
            ;;
        --off)
            set_diagnostics_status false
            exit 0
            ;;
        *)
            echo "Invalid argument. Use --on or --off to explicitly set diagnostics status."
            exit 1
            ;;
    esac
fi

# If no arguments provided, toggle the current status
if [[ $current_status == "true" ]]; then
    set_diagnostics_status false
else
    set_diagnostics_status true
fi
