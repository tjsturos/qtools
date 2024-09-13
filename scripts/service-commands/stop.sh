#!/bin/bash
# HELP: Stops the node application service. Will also clean up any leftover node processes (if any).
# Usage: qtools stop
# Usage: qtools stop --quick

sudo systemctl stop $QUIL_SERVICE_NAME.service
wait

if [ "$1" == "--quick" ]; then
    echo "Quick stop mode, skipping backup and cleanup."
else
    qtools backup-store

    # Disable backups after stopping the service
    qtools toggle-backups --off

    # Disable diagnostics
    qtools toggle-diagnostics --off

    # Disable statistics
    qtools toggle-statistics --off


fi
# and to make sure any stray node commands are exited
pgrep -f node | grep -v $$ | xargs -r sudo kill -9