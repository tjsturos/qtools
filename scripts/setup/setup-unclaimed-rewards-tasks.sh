#!/bin/bash

# HELP: Sets up launchd tasks to record unclaimed rewards hourly, weekly, and monthly
# Usage: qtools setup-unclaimed-rewards-tasks

# Function to create and load a launchd plist
create_and_load_plist() {
    local interval=$1
    local plist_name="com.qtools.record_unclaimed_rewards_$interval.plist"
    local plist_path="$LAUNCHD_PLIST_DIR/$plist_name"

    # Create the plist file
    cat > "$plist_path" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.qtools.record_unclaimed_rewards_$interval</string>
    <key>ProgramArguments</key>
    <array>
        <string>$QTOOLS_BIN_PATH</string>
        <string>record-unclaimed-rewards</string>
        <string>$interval</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
EOF

    # Add specific interval settings
    case $interval in
        hourly)
            echo "        <key>Minute</key><integer>0</integer>" >> "$plist_path"
            ;;
        weekly)
            echo "        <key>Weekday</key><integer>0</integer>" >> "$plist_path"
            echo "        <key>Hour</key><integer>0</integer>" >> "$plist_path"
            echo "        <key>Minute</key><integer>0</integer>" >> "$plist_path"
            ;;
        monthly)
            echo "        <key>Day</key><integer>1</integer>" >> "$plist_path"
            echo "        <key>Hour</key><integer>0</integer>" >> "$plist_path"
            echo "        <key>Minute</key><integer>0</integer>" >> "$plist_path"
            ;;
    esac

    # Close the plist file
    cat >> "$plist_path" <<EOF
    </dict>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/record_unclaimed_rewards_$interval.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/record_unclaimed_rewards_$interval.log</string>
</dict>
</plist>
EOF

    # Load the plist
    launchctl load -w "$plist_path"
    log "Created and loaded $interval task: $plist_path"
}

# Create and load tasks for each interval
create_and_load_plist "hourly"
create_and_load_plist "weekly"
create_and_load_plist "monthly"

log "Unclaimed rewards recording tasks have been set up for hourly, weekly, and monthly intervals."