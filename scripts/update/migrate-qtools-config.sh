#!/bin/bash

check_and_add_keys() {
    yq eval-all '
        select(fileIndex == 0) * select(fileIndex == 1)
    ' "$QTOOLS_PATH/config.yml" "$QTOOLS_PATH/config.sample.yml" > "$QTOOLS_PATH/config_merged.yml"

    mv "$QTOOLS_PATH/config_merged.yml" "$QTOOLS_PATH/config.yml"

    echo "Config migration completed. All missing keys have been added."
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

map_values_to_new_field() {
    local old_field="$1"
    local new_field="$2"
    local default_value="$3"

    yq eval -i "$new_field = $old_field // \"$default_value\"" $QTOOLS_PATH/config.yml
}

update_backup_settings() {
    map_values_to_new_field ".settings.backups.enabled" ".scheduled_tasks.backup.enabled" false
    map_values_to_new_field ".settings.backups.node_backup_dir" ".scheduled_tasks.backup.node_backup_name" ""
    map_values_to_new_field ".settings.backups.backup_url" ".scheduled_tasks.backup.backup_url" ""
    map_values_to_new_field ".settings.backups.remote_user" ".scheduled_tasks.backup.remote_user" ""
    map_values_to_new_field ".settings.backups.ssh_key_path" ".scheduled_tasks.backup.ssh_key_path" ""
    map_values_to_new_field ".settings.backups.remote_backup_dir" ".scheduled_tasks.backup.remote_backup_dir" ""
    
    echo "Updated backup settings"
}

VERSION_2() {
    local VERSION=2
    current_version=$(yq eval '.qtools_version // "0"' "$QTOOLS_PATH/config.yml")
    echo "Current version: $current_version vs $VERSION"
    if [ "$current_version" -lt "$VERSION" ]; then
        echo "Migrating config.yml to version 2"
        
        update_backup_settings
        
        # Update qtools_version to 2
        yq eval -i '.qtools_version = 2' "$QTOOLS_PATH/config.yml"
        echo "Updated qtools_version to 2"
    fi
}
# Version 1 was the unversioned config.

VERSION_3() {
    local VERSION=3
    current_version=$(yq eval '.qtools_version // "0"' "$QTOOLS_PATH/config.yml")
    echo "Current version: $current_version vs $VERSION"
    if [ "$current_version" -lt "$VERSION" ]; then
        echo "Migrating config.yml to version 3"
        yq eval -i '.qtools_version = 3' "$QTOOLS_PATH/config.yml"
        echo "Updated qtools_version to 3"
    fi
}
# run the version migration
VERSION_2
VERSION_3


