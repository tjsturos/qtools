#!/bin/bash
# HELP: Toggles statistics on or off in the qtools configuration.
# PARAM: --on: Explicitly turn statistics on
# PARAM: --off: Explicitly turn statistics off
# Usage: qtools toggle-statistics [--on|--off]

# Function to set statistics status
set_statistics_status() {
    local status=$1
    yq -i ".settings.statistics.enabled = $status" $QTOOLS_CONFIG_FILE
    echo "Statistics have been turned $([[ $status == true ]] && echo "on" || echo "off")."
}

# Check current statistics status
current_status=$(yq '.settings.statistics.enabled // true' $QTOOLS_CONFIG_FILE)

# Parse command line arguments
if [[ $# -eq 1 ]]; then
    case $1 in
        --on)
            set_statistics_status true
            sudo systemctl start $STATISTICS_SERVICE_NAME
            exit 0
            ;;
        --off)
            set_statistics_status false
            sudo systemctl stop $STATISTICS_SERVICE_NAME
            exit 0
            ;;
        *)
            echo "Invalid argument. Use --on or --off to explicitly set statistics status."
            exit 1
            ;;
    esac
fi

# If no arguments provided, toggle the current status
if [[ $current_status == "true" ]]; then
    set_statistics_status false
    sudo systemctl stop $STATISTICS_SERVICE_NAME
else
    set_statistics_status true
    sudo systemctl start $STATISTICS_SERVICE_NAME
fi
