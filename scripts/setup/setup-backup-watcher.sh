#!/bin/bash

# HELP: Sets up a launchd task to watch for changes in the .config/store directory and trigger a backup
# Usage: qtools setup-backup-watcher

# Function to create and load a launchd plist for backup watcher
create_and_load_backup_watcher_plist() {
    local plist_name="com.qtools.backup_watcher.plist"
    local plist_path="$LAUNCHD_PLIST_DIR/$plist_name"

    # Check if the plist already exists
    if [ -f "$plist_path" ]; then
        log "Existing backup watcher task found. Removing and recreating..."
        # Unload the existing plist
        launchctl unload "$plist_path" 2>/dev/null
        # Remove the existing plist file
        sudo rm "$plist_path"
    fi

    # Create the plist file
    cat > "$plist_path" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.qtools.backup_watcher</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>qtools backup-store</string>
    </array>
    <key>WatchPaths</key>
    <array>
        <string>$QUIL_NODE_PATH/.config/store</string>
        <string>$QUIL_NODE_PATH/.config</string>
    </array>
    <key>KeepAlive</key>
    <dict>
        <key>NetworkState</key>
        <true/>
        <key>OtherJobEnabled</key>
        <dict>
            <key>com.quilibrium.$QUIL_SERVICE_NAME</key>
            <true/>
        </dict>
    </dict>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$HOME/go/bin:/opt/homebrew/bin</string>
        <key>QTOOLS_PATH</key>
        <string>$QTOOLS_PATH</string>
        <key>QTOOLS_CONFIG_FILE</key>
        <string>$QTOOLS_CONFIG_FILE</string>
        <key>QUIL_PATH</key>
        <string>$QUIL_PATH</string>
        <key>QUIL_NODE_PATH</key>
        <string>$QUIL_NODE_PATH</string>
        <key>QUIL_CLIENT_PATH</key>
        <string>$QUIL_CLIENT_PATH</string>
        <key>QUIL_GO_NODE_BIN</key>
        <string>$QUIL_GO_NODE_BIN</string>
        <key>QUIL_QCLIENT_BIN</key>
        <string>$QUIL_QCLIENT_BIN</string>
        <key>SSH_KEY_PATH</key>
        <string>$(yq '.settings.backups.ssh_key_path' "$QTOOLS_CONFIG_FILE")</string>
        <key>REMOTE_USER</key>
        <string>$(yq '.settings.backups.remote_user' "$QTOOLS_CONFIG_FILE")</string>
        <key>REMOTE_URL</key>
        <string>$(yq '.settings.backups.backup_url' "$QTOOLS_CONFIG_FILE")</string>
    </dict>
    <key>StandardOutPath</key>
    <string>$QTOOLS_PATH/backup_watcher.log</string>
    <key>StandardErrorPath</key>
    <string>$QTOOLS_PATH/backup_watcher.log</string>
    <key>ThrottleInterval</key>
    <integer>60</integer>
</dict>
</plist>
EOF

    # Load the plist
    launchctl load -w "$plist_path"
    log "Created and loaded backup watcher task: $plist_path"
}

# Create and load the backup watcher task
create_and_load_backup_watcher_plist

log "Backup watcher task has been set up to monitor changes in $QUIL_NODE_PATH/.config/store"