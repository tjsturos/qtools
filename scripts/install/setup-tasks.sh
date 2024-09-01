#!/bin/bash
# HELP: Installs all the automated tasks for this node. Sets up self-update, node updates, and unclaimed balance recording tasks.
log "Setting up automated tasks using launchd..."

# On macOS, we'll use launchd instead of cron
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
mkdir -p $LAUNCH_AGENTS_DIR

# Set up other tasks
qtools setup-update-node-task
qtools setup-update-qtools-task
qtools setup-unclaimed-rewards-tasks
qtools setup-backup-watcher-task
qtools setup-node-task

log "Automated tasks have been set up using launchd"
