#!/bin/bash
# HELP: Installs all the automated tasks for this node. Sets up self-update, node updates, and unclaimed balance recording tasks.
log "Setting up automated tasks using launchd..."

# On macOS, we'll use launchd instead of cron
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
mkdir -p $LAUNCH_AGENTS_DIR
# Unload and delete old tasks
log "Unloading and deleting old tasks..."

# Get a list of all plist files in the LaunchAgents directory
PLIST_FILES=$(ls $LAUNCH_AGENTS_DIR/*.plist 2>/dev/null)

if [ -n "$PLIST_FILES" ]; then
    for plist in $PLIST_FILES; do
        # Extract the task name from the plist file name
        task_name=$(basename "$plist" .plist)
        
        # Check if the task is related to qtools or quilibrium
        if [[ $task_name == com.qtools.* ]] || [[ $task_name == com.$USER.$QUIL_SERVICE_NAME ]]; then
            log "Unloading $task_name..."
            launchctl unload "$plist" 2>/dev/null
            log "Deleting $task_name..."
            rm "$plist"
        fi
    done
    log "Old tasks have been unloaded and deleted."
else
    log "No existing tasks found in $LAUNCH_AGENTS_DIR"
fi


# Set up other tasks
qtools setup-update-node-task
qtools setup-update-qtools-task
qtools setup-unclaimed-rewards-tasks
qtools setup-backup-watcher-task
qtools setup-node-task

log "Automated tasks have been set up using launchd"
