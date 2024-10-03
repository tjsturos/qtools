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

        # Add default scheduled tasks for updates
        yq eval -i '
            .scheduled_tasks.updates.qtools.enabled = .scheduled_tasks.updates.qtools.enabled // true |
            .scheduled_tasks.updates.qtools.cron_expression = .scheduled_tasks.updates.qtools.cron_expression // "" |
            .scheduled_tasks.updates.node.enabled = .scheduled_tasks.updates.node.enabled // true |
            .scheduled_tasks.updates.node.cron_expression = .scheduled_tasks.updates.node.cron_expression // "" |
            .scheduled_tasks.updates.system.enabled = .scheduled_tasks.updates.system.enabled // false |
            .scheduled_tasks.updates.system.cron_expression = .scheduled_tasks.updates.system.cron_expression // ""
        ' "$QTOOLS_PATH/config.yml"

        # Add default scheduled tasks for statistics
        # Add default scheduled tasks for logs, statistics, and diagnostics
        yq eval -i '
            .scheduled_tasks.logs.enabled = .scheduled_tasks.logs.enabled // false |
            .scheduled_tasks.logs.cron_expression = .scheduled_tasks.logs.cron_expression // "" |
            .scheduled_tasks.statistics.enabled = .scheduled_tasks.statistics.enabled // true |
            .scheduled_tasks.statistics.service_name = .scheduled_tasks.statistics.service_name // "quil_statistics" |
            .scheduled_tasks.statistics.prometheus.endpoint = .scheduled_tasks.statistics.prometheus.endpoint // "https://stats.qcommander.sh:9090/api/v1/write" |
            .scheduled_tasks.statistics.prometheus.tls_config.cert_file = .scheduled_tasks.statistics.prometheus.tls_config.cert_file // "/files/grafana.cert" |
            .scheduled_tasks.statistics.prometheus.tls_config.key_file = .scheduled_tasks.statistics.prometheus.tls_config.key_file // "/files/grafana.key" |
            .scheduled_tasks.statistics.prometheus.tls_config.server_name = .scheduled_tasks.statistics.prometheus.tls_config.server_name // "stats.qcommander.sh" |
            .scheduled_tasks.statistics.loki.endpoint = .scheduled_tasks.statistics.loki.endpoint // "https://stats.qcommander.sh:3100/loki/api/v1/push" |
            .scheduled_tasks.statistics.loki.tls_config.cert_file = .scheduled_tasks.statistics.loki.tls_config.cert_file // "/files/grafana.cert" |
            .scheduled_tasks.statistics.loki.tls_config.key_file = .scheduled_tasks.statistics.loki.tls_config.key_file // "/files/grafana.key" |
            .scheduled_tasks.statistics.loki.tls_config.server_name = .scheduled_tasks.statistics.loki.tls_config.server_name // "stats.qcommander.sh" |
            .scheduled_tasks.statistics.grafana.alloy.enabled = .scheduled_tasks.statistics.grafana.alloy.enabled // true |
            .scheduled_tasks.statistics.grafana.alloy.template_file = .scheduled_tasks.statistics.grafana.alloy.template_file // "/files/alloy.config" |
            .scheduled_tasks.statistics.grafana.alloy.config_file = .scheduled_tasks.statistics.grafana.alloy.config_file // "/etc/alloy/alloy.conf" |
            .scheduled_tasks.diagnostics.enabled = .scheduled_tasks.diagnostics.enabled // true |
            .scheduled_tasks.diagnostics.cron_expression = .scheduled_tasks.diagnostics.cron_expression // ""
        ' "$QTOOLS_PATH/config.yml"

        echo "Added default scheduled tasks for logs, statistics, and diagnostics"

        echo "Added default scheduled tasks for updates"

        echo "Copied .settings.backups to .scheduled_tasks.backup fields"
    fi
}

# run the version migration
VERSION_1


