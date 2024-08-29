#!/bin/bash
# HELP: Installs all the automated tasks for this node. Currently, it runs qtools & node updates, as well as backups (if enabled) every 10 minutes. It also records the unclaimed balances on different intervals (every hour, 1x a day, 1x week, 1x month).
log "Updating this user's crontab for automated tasks..."

# On macOS, we'll use launchd instead of cron
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
mkdir -p $LAUNCH_AGENTS_DIR

# Create a plist file for our tasks
cat << EOF > $LAUNCH_AGENTS_DIR/com.qtools.tasks.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.qtools.tasks</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>$QTOOLS_PATH/qtools.sh self-update && $QTOOLS_PATH/qtools.sh update-node</string>
    </array>
    <key>StartInterval</key>
    <integer>600</integer>
</dict>
</plist>
EOF

# Load the plist file
launchctl load $LAUNCH_AGENTS_DIR/com.qtools.tasks.plist

log "Automated tasks have been set up using launchd"
