#!/bin/bash
log "Starting self-update"

cd $QTOOLS_PATH

log "Fetching latest qTools changes..."
git pull
log "Changes fetched."
qtools add-auto-complete
qtools update-source-url
qtools install-cron

source ~/.bashrc