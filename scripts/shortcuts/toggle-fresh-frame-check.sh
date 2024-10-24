#!/bin/bash
# HELP: Toggles fresh frame check on or off in the qtools configuration.
# PARAM: --on: Explicitly turn fresh frame check on
# PARAM: --off: Explicitly turn fresh frame check off
# Usage: qtools toggle-fresh-frame-check [--on|--off]

# Function to set statistics status
set_fresh_frame_check_status() {
    local status=$1
    yq -i ".scheduled_tasks.check_if_fresh_frames.enabled = $status" $QTOOLS_CONFIG_FILE
    echo "Fresh frame check has been turned $([[ $status == true ]] && echo "on" || echo "off")."
    qtools update-cron
}

# Check current statistics status
current_status=$(yq '.scheduled_tasks.check_if_fresh_frames.enabled' $QTOOLS_CONFIG_FILE)

# Parse command line arguments
if [[ $# -eq 1 ]]; then
    case $1 in
        --on)
            set_fresh_frame_check_status true
            exit 0
            ;;
        --off)
            set_fresh_frame_check_status false
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
    set_fresh_frame_check_status false
else
    set_fresh_frame_check_status true
fi
