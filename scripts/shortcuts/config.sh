# IGNORE - This is the old config script. Use 'qtools config' command instead.
# Handle config commands for qtools and quil configs
# Usage: config <qtools|quil> <get|set> <path> [--value <value>]
# Example: config qtools get scheduled_tasks backup backup_url
# Example: config qtools set scheduled_tasks backup backup_url --value https://backups.example.com


# Define shortcuts for common config paths
declare -A CONFIG_SHORTCUTS=(
    ["backup-url"]=".scheduled_tasks.backup.backup_url"
    ["backup-user"]=".scheduled_tasks.backup.remote_user"
    ["backup-key"]=".scheduled_tasks.backup.ssh_key_path"
    ["backup-dir"]=".scheduled_tasks.backup.remote_backup_dir"
    ["backup-enabled"]=".scheduled_tasks.backup.enabled"
    ["backup-cron"]=".scheduled_tasks.backup.cron_expression"
    ["node-updates"]=".scheduled_tasks.updates.node.enabled"
    ["node-update-cron"]=".scheduled_tasks.updates.node.cron_expression"
    ["node-skip-version"]=".scheduled_tasks.updates.node.skip_version"
    ["qtools-updates"]=".scheduled_tasks.updates.qtools.enabled"
    ["qtools-update-cron"]=".scheduled_tasks.updates.qtools.cron_expression"
    ["system-updates"]=".scheduled_tasks.updates.system.enabled"
    ["system-update-cron"]=".scheduled_tasks.updates.system.cron_expression"
    ["worker-count"]=".data_worker_service.worker_count"
    ["base-port"]=".data_worker_service.base_port"
    ["service-debug"]=".service.debug"
    ["service-testnet"]=".service.testnet"
    ["service-args"]=".service.args"
    ["listen-addr"]=".settings.listenAddr"
    ["sync-timeout"]=".engine.syncTimeout"
    ["ping-timeout"]=".p2p.pingTimeout"
)

config() {
    local config_type="$1"
    local operation="$2"
    local value=""
    local config_file=""

    # Validate config type
    if [[ "$config_type" != "qtools" && "$config_type" != "quil" ]]; then
        echo "Error: First argument must be either 'qtools' or 'quil'"
        echo "Usage: config <qtools|quil> <get|set> <path> [--value <value>]"
        return 1
    fi

    # Set config file based on type
    if [[ "$config_type" == "qtools" ]]; then
        config_file="$QTOOLS_CONFIG_FILE"
    else
        config_file="$QUIL_CONFIG_FILE"
    fi

    # Validate operation
    if [[ "$operation" != "get" && "$operation" != "set" ]]; then
        echo "Error: Second argument must be either 'get' or 'set'"
        echo "Usage: config <qtools|quil> <get|set> <path> [--value <value>]"
        return 1
    fi

    # Remove first two arguments to get the path
    shift 2
    local path=""

    if [[ -n "${CONFIG_SHORTCUTS[$1]}" ]]; then
        path="${CONFIG_SHORTCUTS[$1]}"
        shift
    else
        while [[ $# -gt 0 && "$1" != "--value" && "$1" != "-v" ]]; do
            if [[ -z "$path" ]]; then
                path=".$1"
            else
                path="$path.$1"
            fi
            shift
        done
    fi

    # Build the yaml path


    if [[ "$operation" == "get" ]]; then
        yq eval "$path" "$config_file"
    else
        # For set operations, require a value
        if [[ "$1" == "--value" || "$1" == "-v" ]]; then
            shift
            value="$1"
            if [[ -z "$value" ]]; then
                echo "Error: No value provided after --value/-v flag"
                return 1
            fi
            yq -i "$path = \"$value\"" "$config_file"
            echo "Set $path to $value"
            echo "You may need to restart the service (qtools restart) to apply the changes"
        else
            echo "Error: Set operation requires --value or -v flag with a value"
            return 1
        fi
    fi
}

config "$@"
