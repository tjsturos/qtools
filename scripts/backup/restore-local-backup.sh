#!/bin/bash
# HELP: Restores a local backup of this node\'s .config directory.

# Backup existing .config directory if it exists
# PARAM: --overwrite: Skip prompt and overwrite existing .config-old directory

if [ -d "$QUIL_NODE_PATH/.config" ]; then
    if [ -d "$QUIL_NODE_PATH/.config-old" ]; then
        if [ "$1" == "--overwrite" ]; then
            rm -rf "$QUIL_NODE_PATH/.config-old"
            mv "$QUIL_NODE_PATH/.config" "$QUIL_NODE_PATH/.config-old"
            log "Existing .config directory moved to .config-old (overwritten)"
        else
            read -p "'.config-old' already exists. Do you want to overwrite it? (y/n): " choice
            if [[ $choice == [Yy]* ]]; then
                rm -rf "$QUIL_NODE_PATH/.config-old"
                mv "$QUIL_NODE_PATH/.config" "$QUIL_NODE_PATH/.config-old"
                log "Existing .config directory moved to .config-old (overwritten)"
            else
                i=2
                while [ -d "$QUIL_NODE_PATH/.config-old-$i" ]; do
                    ((i++))
                done
                mv "$QUIL_NODE_PATH/.config" "$QUIL_NODE_PATH/.config-old-$i"
                log "Existing .config directory moved to .config-old-$i"
            fi
        fi
    else
        mv "$QUIL_NODE_PATH/.config" "$QUIL_NODE_PATH/.config-old"
        log "Existing .config directory moved to .config-old"
    fi
fi

# Create .config directory if it doesn't exist
mkdir -p "$QUIL_NODE_PATH/.config"

# Restore .config directory
rsync -avzrP --delete-after "$BACKUP_DIR/.config/" "$QUIL_NODE_PATH/.config"

log "Quilibrium $QUIL_NODE_PATH/.config directory restored from $BACKUP_DIR"
