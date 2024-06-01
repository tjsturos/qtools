#!/bin/bash
log "Starting qtools update..."

cd $QTOOLS_PATH

log "Fetching latest qtools changes..."
git pull
log "Changes fetched."
qtools add-auto-complete
qtools update-source-url
qtools install-cron

source ~/.bashrc

log "Finished qtools update.