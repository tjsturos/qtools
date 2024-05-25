#!/bin/bash

append_to_file() {
    FILE="$1"
    CONTENT="$2"

    if ! grep -qFx "$CONTENT" $FILE; then
        log "Adding $CONTENT to $FILE"
        echo "$CONTENT" >> $FILE
    else
        log "$CONTENT already found in $FILE. Skipping."
    fi
}

  # Define TOOL_PATH (example path, change as needed)
export QTOOLS_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

append_to_file ~/.bashrc "export QTOOLS_PATH=\"$QTOOLS_PATH\""

# Reload ~/.bashrc to apply changes
source ~/.bashrc
