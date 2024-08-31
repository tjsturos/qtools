#!/bin/bash
# HELP: Starts the node application service. If .settings.debug is set to true or use --debug flag, this will start node in debug mode.
# PARAM: --debug: will start the node application in debug mode
# Usage: qtools start
# Usage: qtools start --debug

# get settings
DEBUG_MODE="$(yq '.settings.debug' $QTOOLS_CONFIG_FILE)"

if [[ "$1" == "--debug" ]]; then
    DEBUG_MODE="true"
fi

# macOS (launchd)
if [[ "$DEBUG_MODE" == "true" ]]; then
    launchctl setenv DEBUG_MODE true
else
    launchctl setenv DEBUG_MODE false
fi

# Move the current log file to old and keep only one old log file
if [[ -f "$QUIL_LOG_FILE" ]]; then
    if [[ -f "${QUIL_LOG_FILE}.old" ]]; then
        rm "${QUIL_LOG_FILE}.old"
    fi
    mv "$QUIL_LOG_FILE" "${QUIL_LOG_FILE}.old"
fi

# Create a new empty log file
touch "$QUIL_LOG_FILE"

log "Moved current log file to ${QUIL_LOG_FILE}.old and created a new log file."

# Check if the service is already loaded
if launchctl list | grep -q "$QUIL_SERVICE_NAME"; then
    log "Node service is already running. Restarting..."
    launchctl unload "$QUIL_SERVICE_FILE"
fi

launchctl load -w "$QUIL_SERVICE_FILE"

# Wait for a moment to ensure the service has started
sleep 2

# Check if the service is running
if launchctl list | grep -q "$QUIL_SERVICE_NAME"; then
    log "Node service started successfully."
else
    log "Failed to start node service. Please check the logs for more information."
fi

