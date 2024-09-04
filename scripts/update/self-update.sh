#!/bin/bash
# HELP: Updates the Qtools suite, as well as adding auto-complete and installing any new cron tasks.

log "Starting qtools update..."

cd $QTOOLS_PATH

git pull &> /dev/null
log "Changes fetched."
qtools add-auto-complete
qtools setup-tasks

source ~/.zshrc

log "Finished qtools update."

# exit 0
