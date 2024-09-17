#!/bin/bash
# HELP: Toggles backups on or off in the qtools configuration.
# PARAM: --on: Explicitly turn backups on
# PARAM: --off: Explicitly turn backups off
# Usage: qtools toggle-backups [--on|--off]

# Function to set backup status
set_backup_status() {
    local status=$1
    yq -i ".settings.backups.enabled = $status" $QTOOLS_CONFIG_FILE
    echo "Backups have been turned $([[ $status == true ]] && echo "on" || echo "off")."
}

# Check current backup status
current_status=$(yq '.settings.backups.enabled' $QTOOLS_CONFIG_FILE)

# Parse command line arguments
if [[ $# -eq 1 ]]; then
    case $1 in
        --on)
            if [ "$current_status" == "true" ]; then
                echo "Backups are already enabled."
                exit 0
            fi
            set_backup_status true
            exit 0
            ;;
        --off)
            if [ "$current_status" == "false" ]; then
                echo "Backups are already disabled."
                exit 0
            fi
            set_backup_status false
            exit 0
            ;;
        *)
            echo "Invalid argument. Use --on or --off to explicitly set backup status."
            exit 1
            ;;
    esac
fi

# If no arguments provided, toggle the current status
if [[ $current_status == "true" ]]; then
    set_backup_status false
else
    set_backup_status true
fi
