#!/bin/bash
QTOOLS_CONFIG_FILE_SAMPLE="$QTOOLS_PATH/config.sample.yml"
QTOOLS_CONFIG_FILE_MERGED="$QTOOLS_PATH/config_merged.yml"

# Validate and restore config.sample.yml if corrupted
validate_and_restore_sample_config() {
    # Check if sample config exists and is valid YAML
    if [ -f "$QTOOLS_CONFIG_FILE_SAMPLE" ]; then
        if ! yq eval '.' "$QTOOLS_CONFIG_FILE_SAMPLE" > /dev/null 2>&1; then
            echo "Warning: config.sample.yml appears to be corrupted. Attempting to restore from source..."

            # Try to restore from git if in a git repository
            if [ -d "$QTOOLS_PATH/.git" ]; then
                cd "$QTOOLS_PATH"
                if git checkout HEAD -- config.sample.yml 2>/dev/null; then
                    # Verify the restored file is valid
                    if yq eval '.' "$QTOOLS_CONFIG_FILE_SAMPLE" > /dev/null 2>&1; then
                        echo "Restored config.sample.yml from git repository"
                        return 0
                    else
                        echo "Error: Restored config.sample.yml is still invalid"
                        exit 1
                    fi
                fi
            fi

            # If git restore failed or not a git repo, try to copy from a backup location
            # or remove and let it be recreated (though this shouldn't happen in normal operation)
            echo "Error: Could not restore config.sample.yml. Please restore it manually from the repository."
            exit 1
        fi
    else
        echo "Error: config.sample.yml not found at $QTOOLS_CONFIG_FILE_SAMPLE"
        exit 1
    fi
}

# Validate sample config before proceeding
validate_and_restore_sample_config

check_and_add_keys() {
    yq eval-all '
        select(fileIndex == 0) * select(fileIndex == 1) * select(fileIndex == 0)
    ' "$QTOOLS_CONFIG_FILE" "$QTOOLS_CONFIG_FILE_SAMPLE" > "$QTOOLS_CONFIG_FILE_MERGED"

    mv "$QTOOLS_CONFIG_FILE_MERGED" "$QTOOLS_CONFIG_FILE"

    echo "Config migration completed. All missing keys have been added."
}

# Function to check and add missing keys from config.sample.yml to config.yml
migrate_base_config() {
    check_and_add_keys ""

    echo "Base config migration completed."
}


# Check if config.yml exists
if [ -f "$QTOOLS_CONFIG_FILE" ]; then
    migrate_base_config
else
    echo "Error: $QTOOLS_CONFIG_FILE not found."
    exit 1
fi

map_values_to_new_field() {
    local old_field="$1"
    local new_field="$2"
    local default_value="$3"

    yq eval -i "$new_field = $old_field // \"$default_value\"" $QTOOLS_CONFIG_FILE
    # Only delete if the old field exists
    if yq eval "$old_field" "$QTOOLS_CONFIG_FILE" &>/dev/null; then
        yq eval -i "del($old_field)" $QTOOLS_CONFIG_FILE
    fi
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
    current_version=$(yq eval '.qtools_version // "0"' "$QTOOLS_CONFIG_FILE")
    echo "Current version: $current_version vs $VERSION"
    if [ "$current_version" -lt "$VERSION" ]; then
        echo "Migrating config.yml to version 2"

        update_backup_settings

        # Update qtools_version to 2
        yq eval -i '.qtools_version = 2' "$QTOOLS_CONFIG_FILE"
        echo "Updated qtools_version to 2"
    fi
}
# Version 1 was the unversioned config.

VERSION_3() {
    local VERSION=3
    current_version=$(yq eval '.qtools_version // "0"' "$QTOOLS_CONFIG_FILE")
    echo "Current version: $current_version vs $VERSION"
    if [ "$current_version" -lt "$VERSION" ]; then
        echo "Migrating config.yml to version 3"
        yq eval -i '.qtools_version = 3' "$QTOOLS_CONFIG_FILE"
        echo "Updated qtools_version to 3"
    fi
}

VERSION_5() {
    local VERSION=5
    current_version=$(yq eval '.qtools_version // "0"' "$QTOOLS_CONFIG_FILE")

    echo "Current version: $current_version vs $VERSION"
    if [ "$current_version" -lt "$VERSION" ]; then
        echo "Migrating config.yml to version 5"
        yq eval -i '.qtools_version = 5' "$QTOOLS_CONFIG_FILE"
        get_current_node_version
        get_current_qclient_version
        echo "Updated qtools_version to 5"
    fi
}

VERSION_21() {
    local VERSION=21
    local VERSION=21
    current_version=$(yq eval '.qtools_version // "0"' "$QTOOLS_CONFIG_FILE")
    echo "Current version: $current_version vs $VERSION"
    if [ "$current_version" -lt "$VERSION" ]; then
        echo "Migrating config.yml to version 21"

        # Check if old publish_multiaddrs settings exist and migrate them
        if yq eval '.settings.publish_multiaddr.ssh_key_path' "$QTOOLS_CONFIG_FILE" &>/dev/null; then
            map_values_to_new_field ".settings.publish_multiaddr.ssh_key_path" ".settings.central_server.ssh_key_path"
        fi

        if yq eval '.settings.publish_multiaddr.remote_user' "$QTOOLS_CONFIG_FILE" &>/dev/null; then
            map_values_to_new_field ".settings.publish_multiaddr.remote_user" ".settings.central_server.remote_user"
        fi

        if yq eval '.settings.publish_multiaddrs.remote_host' "$QTOOLS_CONFIG_FILE" &>/dev/null; then
            map_values_to_new_field ".settings.publish_multiaddr.remote_host" ".settings.central_server.remote_host"
        fi

        yq eval -i '.qtools_version = 21' "$QTOOLS_CONFIG_FILE"
        echo "Updated qtools_version to 21"
    fi
}

get_latest_qtools_version() {
    yq eval '.qtools_version // "0"' "$QTOOLS_CONFIG_FILE_SAMPLE"
}

# Version 24: Add clustering worker base ports and master stream port defaults
VERSION_24() {
    local VERSION=24
    current_version=$(yq eval '.qtools_version // "0"' "$QTOOLS_CONFIG_FILE")
    echo "Current version: $current_version vs $VERSION"
    if [ "$current_version" -lt "$VERSION" ]; then
        echo "Migrating config.yml to version 24"
        yq eval -i '.service.clustering.worker_base_p2p_port = (.service.clustering.worker_base_p2p_port // 50000)' "$QTOOLS_CONFIG_FILE"
        yq eval -i '.service.clustering.worker_base_stream_port = (.service.clustering.worker_base_stream_port // 60000)' "$QTOOLS_CONFIG_FILE"
        yq eval -i '.service.clustering.master_stream_port = (.service.clustering.master_stream_port // 8340)' "$QTOOLS_CONFIG_FILE"
        yq eval -i '.qtools_version = 24' "$QTOOLS_CONFIG_FILE"
        echo "Updated qtools_version to 24"
    fi
}

# Version 25: Remove config_carousel functionality (no longer supported)
VERSION_25() {
    local VERSION=25
    current_version=$(yq eval '.qtools_version // "0"' "$QTOOLS_CONFIG_FILE")
    echo "Current version: $current_version vs $VERSION"
    if [ "$current_version" -lt "$VERSION" ]; then
        echo "Migrating config.yml to version 25"

        # Remove config_carousel section if it exists
        config_carousel_value=$(yq eval '.scheduled_tasks.config_carousel' "$QTOOLS_CONFIG_FILE" 2>/dev/null)
        if [ $? -eq 0 ] && [ "$config_carousel_value" != "null" ] && [ -n "$config_carousel_value" ]; then
            yq eval -i 'del(.scheduled_tasks.config_carousel)' "$QTOOLS_CONFIG_FILE"
            echo "Removed config_carousel section (no longer supported)"
        fi

        yq eval -i '.qtools_version = 25' "$QTOOLS_CONFIG_FILE"
        echo "Updated qtools_version to 25"
    fi
}

# Version 26: Add dev.remote_build configuration for fetch-dev-binary script
VERSION_26() {
    local VERSION=26
    current_version=$(yq eval '.qtools_version // "0"' "$QTOOLS_CONFIG_FILE")
    echo "Current version: $current_version vs $VERSION"
    if [ "$current_version" -lt "$VERSION" ]; then
        echo "Migrating config.yml to version 26"

        # Add dev.remote_build section with default empty values if it doesn't exist
        if ! yq eval '.dev.remote_build' "$QTOOLS_CONFIG_FILE" &>/dev/null || [ "$(yq eval '.dev.remote_build' "$QTOOLS_CONFIG_FILE")" == "null" ]; then
            yq eval -i '.dev.remote_build.ssh_user = ""' "$QTOOLS_CONFIG_FILE"
            yq eval -i '.dev.remote_build.ssh_hostname = ""' "$QTOOLS_CONFIG_FILE"
            yq eval -i '.dev.remote_build.file_path = ""' "$QTOOLS_CONFIG_FILE"
            yq eval -i '.dev.remote_build.ssh_identity = ""' "$QTOOLS_CONFIG_FILE"
            echo "Added dev.remote_build configuration section"
        fi

        yq eval -i '.qtools_version = 26' "$QTOOLS_CONFIG_FILE"
        echo "Updated qtools_version to 26"
    fi
}

# Version 27: Add manual mode and worker service configuration
VERSION_27() {
    local VERSION=27
    current_version=$(yq eval '.qtools_version // "0"' "$QTOOLS_CONFIG_FILE")
    echo "Current version: $current_version vs $VERSION"
    if [ "$current_version" -lt "$VERSION" ]; then
        echo "Migrating config.yml to version 27"

        # Migrate old service.gogc to service.worker_service.gogc if it exists
        old_gogc=$(yq eval '.service.gogc // ""' "$QTOOLS_CONFIG_FILE" 2>/dev/null)
        if [ -n "$old_gogc" ] && [ "$old_gogc" != "null" ] && [ "$old_gogc" != '""' ]; then
            yq eval -i '.service.worker_service.gogc = (.service.gogc // "")' "$QTOOLS_CONFIG_FILE"
            yq eval -i 'del(.service.gogc)' "$QTOOLS_CONFIG_FILE"
            echo "Migrated service.gogc to service.worker_service.gogc"
        fi

        # Migrate old service.gomemlimit to service.worker_service.gomemlimit if it exists
        old_gomemlimit=$(yq eval '.service.gomemlimit // ""' "$QTOOLS_CONFIG_FILE" 2>/dev/null)
        if [ -n "$old_gomemlimit" ] && [ "$old_gomemlimit" != "null" ] && [ "$old_gomemlimit" != '""' ]; then
            yq eval -i '.service.worker_service.gomemlimit = (.service.gomemlimit // "")' "$QTOOLS_CONFIG_FILE"
            yq eval -i 'del(.service.gomemlimit)' "$QTOOLS_CONFIG_FILE"
            echo "Migrated service.gomemlimit to service.worker_service.gomemlimit"
        fi

        # Add service.worker_service section if it doesn't exist
        if ! yq eval '.service.worker_service' "$QTOOLS_CONFIG_FILE" &>/dev/null || [ "$(yq eval '.service.worker_service' "$QTOOLS_CONFIG_FILE")" == "null" ]; then
            yq eval -i '.service.worker_service.gogc = ""' "$QTOOLS_CONFIG_FILE"
            yq eval -i '.service.worker_service.gomemlimit = ""' "$QTOOLS_CONFIG_FILE"
            yq eval -i '.service.worker_service.restart_time = "5s"' "$QTOOLS_CONFIG_FILE"
            echo "Added service.worker_service configuration section"
        else
            # Ensure all worker_service fields exist with defaults
            if ! yq eval '.service.worker_service.gogc' "$QTOOLS_CONFIG_FILE" &>/dev/null || [ "$(yq eval '.service.worker_service.gogc' "$QTOOLS_CONFIG_FILE")" == "null" ]; then
                yq eval -i '.service.worker_service.gogc = ""' "$QTOOLS_CONFIG_FILE"
            fi
            if ! yq eval '.service.worker_service.gomemlimit' "$QTOOLS_CONFIG_FILE" &>/dev/null || [ "$(yq eval '.service.worker_service.gomemlimit' "$QTOOLS_CONFIG_FILE")" == "null" ]; then
                yq eval -i '.service.worker_service.gomemlimit = ""' "$QTOOLS_CONFIG_FILE"
            fi
            if ! yq eval '.service.worker_service.restart_time' "$QTOOLS_CONFIG_FILE" &>/dev/null || [ "$(yq eval '.service.worker_service.restart_time' "$QTOOLS_CONFIG_FILE")" == "null" ]; then
                yq eval -i '.service.worker_service.restart_time = "5s"' "$QTOOLS_CONFIG_FILE"
            fi
        fi

        # Add manual section if it doesn't exist
        if ! yq eval '.manual' "$QTOOLS_CONFIG_FILE" &>/dev/null || [ "$(yq eval '.manual' "$QTOOLS_CONFIG_FILE")" == "null" ]; then
            yq eval -i '.manual.enabled = false' "$QTOOLS_CONFIG_FILE"
            yq eval -i '.manual.worker_count = 0' "$QTOOLS_CONFIG_FILE"
            yq eval -i '.manual.local_only = true' "$QTOOLS_CONFIG_FILE"
            echo "Added manual mode configuration section"
        else
            # Ensure all manual fields exist with defaults
            if ! yq eval '.manual.enabled' "$QTOOLS_CONFIG_FILE" &>/dev/null || [ "$(yq eval '.manual.enabled' "$QTOOLS_CONFIG_FILE")" == "null" ]; then
                yq eval -i '.manual.enabled = false' "$QTOOLS_CONFIG_FILE"
            fi
            if ! yq eval '.manual.worker_count' "$QTOOLS_CONFIG_FILE" &>/dev/null || [ "$(yq eval '.manual.worker_count' "$QTOOLS_CONFIG_FILE")" == "null" ]; then
                yq eval -i '.manual.worker_count = 0' "$QTOOLS_CONFIG_FILE"
            fi
            if ! yq eval '.manual.local_only' "$QTOOLS_CONFIG_FILE" &>/dev/null || [ "$(yq eval '.manual.local_only' "$QTOOLS_CONFIG_FILE")" == "null" ]; then
                yq eval -i '.manual.local_only = true' "$QTOOLS_CONFIG_FILE"
            fi
        fi

        yq eval -i '.qtools_version = 27' "$QTOOLS_CONFIG_FILE"
        echo "Updated qtools_version to 27"
    fi
}

# Version 28: Add public IP monitoring configuration
VERSION_28() {
    local VERSION=28
    current_version=$(yq eval '.qtools_version // "0"' "$QTOOLS_CONFIG_FILE")
    echo "Current version: $current_version vs $VERSION"
    if [ "$current_version" -lt "$VERSION" ]; then
        echo "Migrating config.yml to version 28"

        # Add public_ip section if it doesn't exist
        if ! yq eval '.scheduled_tasks.public_ip' "$QTOOLS_CONFIG_FILE" &>/dev/null || [ "$(yq eval '.scheduled_tasks.public_ip' "$QTOOLS_CONFIG_FILE")" == "null" ]; then
            yq eval -i '.scheduled_tasks.public_ip.enabled = false' "$QTOOLS_CONFIG_FILE"
            yq eval -i '.scheduled_tasks.public_ip.cron_expression = ""' "$QTOOLS_CONFIG_FILE"
            yq eval -i '.scheduled_tasks.public_ip.previous_ip = ""' "$QTOOLS_CONFIG_FILE"
            echo "Added scheduled_tasks.public_ip configuration section"
        else
            # Ensure all public_ip fields exist with defaults
            if ! yq eval '.scheduled_tasks.public_ip.enabled' "$QTOOLS_CONFIG_FILE" &>/dev/null || [ "$(yq eval '.scheduled_tasks.public_ip.enabled' "$QTOOLS_CONFIG_FILE")" == "null" ]; then
                yq eval -i '.scheduled_tasks.public_ip.enabled = false' "$QTOOLS_CONFIG_FILE"
            fi
            if ! yq eval '.scheduled_tasks.public_ip.cron_expression' "$QTOOLS_CONFIG_FILE" &>/dev/null || [ "$(yq eval '.scheduled_tasks.public_ip.cron_expression' "$QTOOLS_CONFIG_FILE")" == "null" ]; then
                yq eval -i '.scheduled_tasks.public_ip.cron_expression = ""' "$QTOOLS_CONFIG_FILE"
            fi
            if ! yq eval '.scheduled_tasks.public_ip.previous_ip' "$QTOOLS_CONFIG_FILE" &>/dev/null || [ "$(yq eval '.scheduled_tasks.public_ip.previous_ip' "$QTOOLS_CONFIG_FILE")" == "null" ]; then
                yq eval -i '.scheduled_tasks.public_ip.previous_ip = ""' "$QTOOLS_CONFIG_FILE"
            fi
        fi

        yq eval -i '.qtools_version = 28' "$QTOOLS_CONFIG_FILE"
        echo "Updated qtools_version to 28"
    fi
}

# run the version migration
VERSION_2
VERSION_3
VERSION_5
VERSION_21
VERSION_24
VERSION_25
VERSION_26
VERSION_27
VERSION_28

yq eval -i ".qtools_version = \"$(get_latest_qtools_version)\"" "$QTOOLS_CONFIG_FILE"

