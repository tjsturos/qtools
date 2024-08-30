#!/bin/bash
# HELP: Stops the node application service. Will also clean up any leftover node processes (if any).
# Usage: qtools stop

# otherwise just start the main process
# Stop the service using launchctl
launchctl unload "$QUIL_SERVICE_FILE"

# Check if the service has stopped
if ! launchctl list | grep -q "$QUIL_SERVICE_NAME"; then
    log "Node service stopped successfully."
else
    log "Failed to stop node service. Attempting to force quit..."
    launchctl remove "$QUIL_SERVICE_NAME"
fi
