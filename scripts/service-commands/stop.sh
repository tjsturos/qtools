#!/bin/bash
# HELP: Stops the node application service. Will also clean up any leftover node processes (if any).
# Usage: qtools stop

# otherwise just start the main process
sudo systemctl stop $QUIL_SERVICE_NAME.service

qtools backup-store

# Disable backups after stopping the service
yq -i '.settings.backups.enabled = false' $QTOOLS_CONFIG_FILE

log "Backups have been disabled in the qtools configuration."

wait
# and to make sure any stray node commands are exited
pgrep -f node | grep -v $$ | xargs -r sudo kill -9