#!/bin/bash

# Get the current status
CURRENT_STATUS=$(yq eval '.scheduled_tasks.config_carousel.check_workers.enabled' $QTOOLS_CONFIG_FILE)

MANUAL_STATE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --on)
            MANUAL_STATE="on"
            shift
            ;;
        --off)
            MANUAL_STATE="off"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

enable_worker_check() {
    yq eval -i '.scheduled_tasks.config_carousel.check_workers.enabled = true' $QTOOLS_CONFIG_FILE
    echo "Worker availability checking has been enabled"
}

disable_worker_check() {
    yq eval -i '.scheduled_tasks.config_carousel.check_workers.enabled = false' $QTOOLS_CONFIG_FILE
    echo "Worker availability checking has been disabled"
}

if [ "$MANUAL_STATE" == "on" ]; then
    if [ "$CURRENT_STATUS" == "true" ]; then
        echo "Worker availability checking is already enabled"
        exit 0
    else
        enable_worker_check
    fi
elif [ "$MANUAL_STATE" == "off" ]; then
    if [ "$CURRENT_STATUS" == "false" ]; then
        echo "Worker availability checking is already disabled"
        exit 0
    else
        disable_worker_check
    fi
else
    if [ "$CURRENT_STATUS" == "true" ]; then
        disable_worker_check
    else
        enable_worker_check
    fi
fi

# Update cron to apply changes
qtools update-cron 