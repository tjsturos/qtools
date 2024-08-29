#!/bin/bash
# HELP: Updates the node's service for any changes in the qtools config file.

log "Updating the service..."

# macOS-specific service update
qtools create-launchd-plist
