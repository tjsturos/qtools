#!/bin/bash
# HELP: Sets the service restart time value in the qtools config file
# PARAM: <int>: restart time value in seconds, or "default" to reset to 5s
# Usage: qtools service-set-restart-time <int>
# Usage: qtools service-set-restart-time default

if [ $# -ne 1 ]; then
    echo "Usage: qtools service-set-restart-time <int>"
    echo "       qtools service-set-restart-time default"
    exit 1
fi

if [ "$1" == "default" ]; then
    qtools config set-value service.restart_time "5s" --quiet
    echo "Service restart time reset to default (5s)"
else
    if ! [[ "$1" =~ ^[0-9]+$ ]]; then
        echo "Error: Restart time value must be a positive integer"
        exit 1
    fi
    qtools config set-value service.restart_time "${1}s" --quiet
    echo "Service restart time set to $1s"
fi

qtools update-service

