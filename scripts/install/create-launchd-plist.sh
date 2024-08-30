#!/bin/bash
# HELP: Creates a launchd plist file for the node service on macOS

cat << EOF > "$QUIL_SERVICE_FILE"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.quilibrium.$QUIL_SERVICE_NAME</string>
    <key>ProgramArguments</key>
    <array>
        <string>$QUIL_NODE_PATH/$(get_versioned_node)</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ThrottleInterval</key>
    <integer>5</integer>
    <key>StandardOutPath</key>
    <string>$QUIL_LOG_FILE</string>
    <key>StandardErrorPath</key>
    <string>$QUIL_LOG_FILE</string>
    <key>WorkingDirectory</key>
    <string>$QUIL_NODE_PATH</string>
    <key>Version</key>
    <string>$(echo $(get_versioned_node) | sed -E 's/node-([0-9]+(\.[0-9]+){1,3})-darwin-.*/\1/')</string>
</dict>
</plist>
EOF

log "Created launchd plist file at $QUIL_SERVICE_FILE"
