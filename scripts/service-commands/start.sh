#!/bin/bash
# HELP: Starts the node application service. If .settings.debug is set to true or use --debug flag, this will start node in debug mode.
# PARAM: --debug: will start the node application in debug mode
# Usage: qtools start
# Usage: qtools start --debug

# get settings
DEBUG_MODE="$(yq '.settings.debug' $QTOOLS_CONFIG_FILE)"

if [ "$1" == "--debug" ]; then
    DEBUG_MODE="true"
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS (launchd)
    if [ "$DEBUG_MODE" == "true" ]; then
        launchctl setenv DEBUG_MODE true
    fi
    launchctl load -w "$QUIL_SERVICE_FILE"
else
    # Linux (systemd)
    # ... (existing Linux-specific code)
fi
