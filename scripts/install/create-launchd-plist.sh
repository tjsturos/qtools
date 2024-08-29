#!/bin/bash
# HELP: Creates a launchd plist file for the node service on macOS

if [[ "$OSTYPE" == "darwin"* ]]; then
    cat << EOF > "$QUIL_SERVICE_FILE"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.$USER.$QUIL_SERVICE_NAME</string>
    <key>ProgramArguments</key>
    <array>
        <string>$QUIL_NODE_PATH/$(get_versioned_node)</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/$QUIL_SERVICE_NAME.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/$QUIL_SERVICE_NAME.err.log</string>
    <key>WorkingDirectory</key>
    <string>$QUIL_NODE_PATH</string>
</dict>
</plist>
EOF
    log "Created launchd plist file at $QUIL_SERVICE_FILE"
else
    log "This script is only for macOS systems"
fi