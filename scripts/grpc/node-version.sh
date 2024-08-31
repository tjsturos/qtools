#!/bin/bash
# HELP: Prints this node's version that is running in the service.

# Get the node version from the plist file created in create-launchd-plist.sh
CURRENT_VERSION=$(plutil -p "$QUIL_SERVICE_FILE" | grep Version | awk -F'"' '{print $4}')

# Set the current version in the configuration file
set_current_version "$CURRENT_VERSION"

# Print the current version
echo "$CURRENT_VERSION"
