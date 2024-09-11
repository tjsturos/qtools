#!/bin/bash
# HELP: Starts the node application service. If .settings.debug is set to true or use --debug flag, this will start node in debug mode.
# PARAM: --debug: will start the node application in debug mode
# Usage: qtools start
# TODO: qtools start --debug

# get settings
DEBUG_MODE="$(yq '.settings.debug' $QTOOLS_CONFIG_FILE)"

if [ "$1" == "--debug" ]; then
    DEBUG_MODE="true"
fi

# TODO: add args to service file

sudo systemctl start $QUIL_SERVICE_NAME.service

# Enable diagnostics
qtools toggle-diagnostics --on

echo "Diagnostics have been enabled."

# Enable statistics
qtools toggle-statistics --on

echo "Statistics have been enabled."
