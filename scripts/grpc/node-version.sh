#!/bin/bash
# HELP: Prints this node's version that is running in the service.

# For macOS, we use launchctl to get the service information
CURRENT_VERSION=$(launchctl list | grep "$QUIL_SERVICE_NAME" | awk '{print $3}' | xargs plutil -p | grep CFBundleVersion | awk -F'"' '{print $4}')

# Set the current version in the configuration file
set_current_version "$CURRENT_VERSION"

# Print the current version
echo "$CURRENT_VERSION"
