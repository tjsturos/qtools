#!/bin/bash
# HELP: Starts the node application service. If .settings.debug is set to true or use --debug flag, this will start node in debug mode.
# PARAM: --debug: will start the node application in debug mode
# Usage: qtools start
# Usage: qtools start --debug

# Get settings
DEBUG_MODE="$(yq '.settings.debug' $QTOOLS_CONFIG_FILE)"

if [[ "$1" == "--debug" ]]; then
    DEBUG_MODE="true"
fi

# Stop the service if it's running
if launchctl list | grep -q "$QUIL_SERVICE_NAME"; then
    log "Stopping the node service..."
    launchctl unload "$QUIL_SERVICE_FILE"
fi

# Check if the plist file needs to be updated
CURRENT_DEBUG_STATUS=$(grep -- "--debug" "$QUIL_SERVICE_FILE" || echo "")
PLIST_NEEDS_UPDATE=false

if [[ "$DEBUG_MODE" == "true" && -z "$CURRENT_DEBUG_STATUS" ]]; then
    PLIST_NEEDS_UPDATE=true
elif [[ "$DEBUG_MODE" != "true" && -n "$CURRENT_DEBUG_STATUS" ]]; then
    PLIST_NEEDS_UPDATE=true
fi

# Update the plist file if needed
if [[ "$PLIST_NEEDS_UPDATE" == "true" ]]; then
    if [[ "$DEBUG_MODE" == "true" ]]; then
        qtools create-launchd-plist --debug
    else
        qtools create-launchd-plist
    fi
    log "Updated launchd plist file."
fi

# Move the current log file to old and keep only one old log file
if [[ -f "$QUIL_LOG_FILE" ]]; then
    if [[ -f "${QUIL_LOG_FILE}.old" ]]; then
        rm "${QUIL_LOG_FILE}.old"
    fi
    mv "$QUIL_LOG_FILE" "${QUIL_LOG_FILE}.old"
fi

echo "$QUIL_LOG_FILE"
# Create a new empty log file
touch "$QUIL_LOG_FILE"

log "Moved current log file to ${QUIL_LOG_FILE}.old and created a new log file."

# Start the service
launchctl load -w "$QUIL_SERVICE_FILE"

# Wait for a moment to ensure the service has started
sleep 2

# Check if the service is running
if launchctl list | grep -q "$QUIL_SERVICE_NAME"; then
    log "Node service started successfully."
else
    log "Failed to start node service. Please check the logs for more information."
fi

