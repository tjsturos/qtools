#!/bin/bash
# HELP: Stops the node application service. Will also clean up any leftover node processes (if any).
# Usage: qtools stop

# otherwise just start the main process
sudo systemctl stop $QUIL_SERVICE_NAME.service

qtools backup-store

# Disable backups after stopping the service
qtools toggle-backups --off

# Disable diagnostics
qtools toggle-diagnostics --off

# Disable statistics
qtools toggle-statistics --off

wait
# and to make sure any stray node commands are exited
pgrep -f node | grep -v $$ | xargs -r sudo kill -9