#!/bin/bash

check_and_add_keys() {
    local parent_key=$1
    local keys=$(yq eval "${parent_key} | keys | .[]" "$QTOOLS_PATH/config.sample.yml")
    
    for key in $keys; do
        local full_key="${parent_key}.${key}"
        # Remove leading dot if parent_key is empty
        full_key="${full_key#.}"
        
        if ! yq eval "${full_key}" "$QTOOLS_PATH/config.yml" > /dev/null 2>&1; then
            # If the key doesn't exist, add it with its value from config.sample.yml
            value=$(yq eval "${full_key}" "$QTOOLS_PATH/config.sample.yml")
            yq eval -i "${full_key} = ${value}" "$QTOOLS_PATH/config.yml"
            echo "Added missing key: ${full_key}"
        else
            # Check if the value is a nested object
            if [[ $(yq eval "${full_key}" "$QTOOLS_PATH/config.sample.yml") == "{}"* ]]; then
                # Recursively check nested keys
                check_and_add_keys "${full_key}"
            fi
        fi
    done
}   

# Function to check and add missing keys from config.sample.yml to config.yml
migrate_base_config() {
    check_and_add_keys ""
    
    echo "Base config migration completed."
}


# Check if config.yml exists
if [ -f "$QTOOLS_PATH/config.yml" ]; then
    migrate_base_config
else
    echo "Error: $QTOOLS_PATH/config.yml not found."
    exit 1
fi

VERSION_1() {
    local VERSION=1
    # Check if .qtools_version is undefined or less than local VERSION
    current_version=$(yq eval '.qtools_version // "0"' "$QTOOLS_PATH/config.yml")
    if [ "$(printf '%s\n' "$current_version" "$VERSION" | sort -V | head -n1)" != "$VERSION" ]; then
        echo "Migrating config.yml to version 1"
        # Copy .settings.backups to .scheduled_tasks.backup fields
        yq eval -i '
            .scheduled_tasks.backup.enabled = .settings.backups.enabled // false |
            .scheduled_tasks.backup.node_backup_name = .settings.backups.node_backup_dir // "" |
            .scheduled_tasks.backup.backup_url = .settings.backups.backup_url // "" |
            .scheduled_tasks.backup.remote_user = .settings.backups.remote_user // "" |
            .scheduled_tasks.backup.ssh_key_path = .settings.backups.ssh_key_path // "" |
            .scheduled_tasks.backup.remote_backup_dir = .settings.backups.remote_backup_dir // ""
        ' "$QTOOLS_PATH/config.yml"

        echo "Copied .settings.backups to .scheduled_tasks.backup fields"
    fi
}

# run the version migration
VERSION_1


