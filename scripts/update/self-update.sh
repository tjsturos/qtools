#!/bin/bash
log "Starting qtools update..."

cd $QTOOLS_PATH

git pull &> /dev/null
log "Changes fetched."
qtools add-auto-complete
qtools update-source-url
qtools install-cron

source ~/.bashrc

log "Finished qtools update."
