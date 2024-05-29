#!/bin/bash

if systemctl is-active --quiet "$QUIL_DEBUG_SERVICE_NAME"; then
    log "Service $QUIL_DEBUG_SERVICE_NAME is running. Stopping the service."
    sudo systemctl stop $QUIL_DEBUG_SERVICE_NAME
    if [ $? -eq 0 ]; then
        log "Service $QUIL_DEBUG_SERVICE_NAME was successfully stopped."
    else
        log "Failed to stop the service $QUIL_DEBUG_SERVICE_NAME."
        return 1  # Exit the function if the service could not be stopped
    fi
fi

if systemctl is-active --quiet "$QUIL_SERVICE_NAME"; then
    log "Service $QUIL_SERVICE_NAME is running. Stopping the service."
    sudo systemctl stop $QUIL_SERVICE_NAME
    if [ $? -eq 0 ]; then
        log "Service $QUIL_SERVICE_NAME was successfully stopped."
    else
        log "Failed to stop the service $QUIL_SERVICE_NAME."
        return 1  # Exit the function if the service could not be stopped
    fi
fi

