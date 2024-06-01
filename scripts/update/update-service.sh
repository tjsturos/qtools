#!/bin/bash

log "Updating the service..."

check_execstart() {
    SERVICE_FILE="$1"
    START_SCRIPT="$2"
    grep -q "^$START_SCRIPT" "$SERVICE_FILE"
}

QUIL_BIN="$(get_versioned_binary)"

# Define the new ExecStart line
NEW_EXECSTART="ExecStart=$QUIL_NODE_PATH/$QUIL_BIN"
 
if [ ! -f "$SYSTEMD_SERVICE_PATH/$QUIL_SERVICE_NAME" ]; then
    log "No ceremonyclient service found.  Initializing service file..."
    cp $QTOOLS_PATH/$QUIL_SERVICE_NAME $SYSTEMD_SERVICE_PATH
fi

# Update the service file if needed
if ! check_execstart "$QUIL_SERVICE_FILE" "$NEW_EXECSTART"; then
    # Use sed to replace the ExecStart line in the service file
    sudo sed -i -e "/^ExecStart=/c\\$NEW_EXECSTART" "$QUIL_SERVICE_FILE"

    # Reload the systemd manager configuration
    sudo systemctl daemon-reload

    log "Systemctl binary version updated to $QUIL_BIN"
fi


if [ ! -f "$QUIL_DEBUG_SERVICE_FILE" ]; then
    log "No debug ceremonyclient service found.  Adding service (inactive)."
    cp $QTOOLS_PATH/$QUIL_DEBUG_SERVICE_NAME $SYSTEMD_SERVICE_PATH
fi

NEW_DEBUG_EXECSTART="ExecStart=$QUIL_NODE_PATH/$QUIL_BIN --debug"
if ! check_execstart "$QUIL_DEBUG_SERVICE_FILE" "$NEW_DEBUG_EXECSTART"; then
    # Use sed to replace the ExecStart line in the service file
    sudo sed -i -e "/^ExecStart=/c\\$NEW_DEBUG_EXECSTART" "$QUIL_DEBUG_SERVICE_FILE"

    # Reload the systemd manager configuration
    sudo systemctl daemon-reload

    log "DEBUG Systemctl binary version updated to $QUIL_BIN"
fi