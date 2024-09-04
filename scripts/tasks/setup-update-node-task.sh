#!/bin/bash

# HELP: Sets up a launchd task to run qtools update-node every 10 minutes
# Usage: qtools setup-update-task

# Function to create and load a launchd plist for the update task
create_and_load_update_task_plist() {
    local plist_name="com.qtools.update_node.plist"
    local plist_path="$LAUNCHD_PLIST_DIR/$plist_name"

    # Check if the plist already exists
    if [ -f "$plist_path" ]; then
        log "Existing update task found. Removing and recreating..."
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
    <string>com.qtools.update_node_task</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>qtools update-node</string>
    </array>
    <key>KeepAlive</key>
    <dict>
        <key>NetworkState</key>
        <true/>
    </dict>
    <key>StartInterval</key>
    <integer>600</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$HOME/go/bin:/opt/homebrew/bin</string>
        <key>QTOOLS_PATH</key>
        <string>$QTOOLS_PATH</string>
    </dict>
    <key>StandardOutPath</key>
    <string>$QTOOLS_PATH/update_task.log</string>
    <key>StandardErrorPath</key>
    <string>$QTOOLS_PATH/update_task.log</string>
</dict>
</plist>
EOF

    # Load the plist
    launchctl load -w "$plist_path"
    log "Created and loaded update task: $plist_path"
}

# Create and load the update task
create_and_load_update_task_plist

log "Update task has been set up to run 'qtools update-node' every 10 minutes"