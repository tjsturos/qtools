#!/bin/bash
# HELP: Prints this node\'s version that is running in the service.

CURRENT_VERSION=$(sudo systemctl status $QUIL_SERVICE_NAME --no-pager | grep -oP "\-([0-9]+\.)+([0-9]+)\-" | head -n 1 | tr -d 'node-')
set_current_version $CURRENT_VERSION
echo $CURRENT_VERSION
