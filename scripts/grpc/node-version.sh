#!/bin/bash
# HELP: Prints this node\'s version that is running in the service.

CURRENT_VERSION=$(launchctl list | grep $QUIL_SERVICE_NAME | awk '{print $3}' | xargs sudo plutil -p | grep CFBundleVersion | awk -F'"' '{print $4}')
set_current_version $CURRENT_VERSION
echo $CURRENT_VERSION
