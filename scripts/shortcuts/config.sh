# Handle config commands for qtools and quil configs
# Usage: config <qtools|quil> <get|set> <path> [--value <value>]
# Example: config qtools get scheduled_tasks backup backup_url
# Example: config qtools set scheduled_tasks backup backup_url --value https://backups.example.com

config() {
    local config_type="$1"
    local operation="$2"
    local value=""
    local config_file=""
    
    # Validate config type
    if [[ "$config_type" != "qtools" && "$config_type" != "quil" ]]; then
        echo "Error: First argument must be either 'qtools' or 'quil'"
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
        return 1
    fi
    
    # Remove first two arguments to get the path
    shift 2
    local path=""
    
    # Build the yaml path
    while [[ $# -gt 0 && "$1" != "--value" && "$1" != "-v" ]]; do
        if [[ -z "$path" ]]; then
            path=".$1"
        else
            path="$path.$1"
        fi
        shift
    done
    
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
        else
            echo "Error: Set operation requires --value or -v flag with a value"
            return 1
        fi
    fi
}

config "$@"
