#!/bin/bash
# HELP: Gets the node application service\'s current status.
# Usage: qtools status

launchctl list | grep "$QUIL_SERVICE_NAME"
