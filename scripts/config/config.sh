#!/bin/bash
# HELP: Manage qtools configuration file - get and set config values, diagnose config file issues
# PARAM: get-value <yml-key> [--default <value>]: Get a configuration value by YAML key path (e.g., service.testnet). Use --default to return a value if key doesn't exist.
# PARAM: set-value <yml-key> <value>: Set a configuration value by YAML key path
# PARAM: validate: Validate that the config file can be read properly
# Usage: qtools config get-value <yml-key> [--default <value>]
# Usage: qtools config set-value <yml-key> <value>
# Usage: qtools config validate

# Function to display usage
usage() {
    echo "Usage: qtools config <command> [arguments]"
    echo ""
    echo "Commands:"
    echo "  get-value <yml-key> [--default <value>]  Get a configuration value by YAML key path"
    echo "                                           Example: qtools config get-value service.testnet"
    echo "                                           Example: qtools config get-value service.testnet --default false"
    echo "                                           Example: qtools config get-value scheduled_tasks.backup.enabled"
    echo ""
    echo "  set-value <yml-key> <value>  Set a configuration value by YAML key path"
    echo "                               Example: qtools config set-value service.testnet true"
    echo "                               Example: qtools config set-value scheduled_tasks.backup.backup_url https://backups.example.com"
    echo ""
    echo "  validate               Validate that the config file can be read properly"
    echo "                         Checks file existence, readability, and YAML validity"
    echo ""
    echo "  help                   Show this help message"
    exit 1
}

# Function to validate config file
validate_config() {
    local config_file="$QTOOLS_CONFIG_FILE"
    local errors=0

    echo "Validating qtools config file: $config_file"
    echo ""

    # Check if file exists
    if [ ! -f "$config_file" ]; then
        echo "❌ ERROR: Config file does not exist at: $config_file"
        errors=$((errors + 1))
        return 1
    fi
    echo "✓ Config file exists"

    # Check if file is readable
    if [ ! -r "$config_file" ]; then
        echo "❌ ERROR: Config file is not readable"
        errors=$((errors + 1))
        return 1
    fi
    echo "✓ Config file is readable"

    # Check if yq is available
    if ! command -v yq >/dev/null 2>&1; then
        echo "❌ ERROR: yq command is not available. Please install yq to read YAML files."
        errors=$((errors + 1))
        return 1
    fi
    echo "✓ yq command is available"

    # Validate YAML syntax
    if ! yq eval '.' "$config_file" >/dev/null 2>&1; then
        echo "❌ ERROR: Config file contains invalid YAML syntax"
        echo ""
        echo "YAML validation error:"
        yq eval '.' "$config_file" 2>&1 | head -20
        errors=$((errors + 1))
        return 1
    fi
    echo "✓ Config file contains valid YAML"

    # Try to read a few common keys to ensure they're accessible
    echo ""
    echo "Testing access to common configuration keys:"

    local test_keys=(
        "service.testnet"
        "service.debug"
        "scheduled_tasks.backup.enabled"
        "settings.log_file"
    )

    local key_errors=0
    for key in "${test_keys[@]}"; do
        if yq eval ".$key" "$config_file" >/dev/null 2>&1; then
            local value=$(yq eval ".$key" "$config_file" 2>/dev/null)
            echo "  ✓ $key = $value"
        else
            echo "  ⚠ $key (not found or inaccessible)"
            key_errors=$((key_errors + 1))
        fi
    done

    echo ""
    if [ $errors -eq 0 ] && [ $key_errors -eq 0 ]; then
        echo "✅ Config file validation passed!"
        return 0
    elif [ $errors -eq 0 ]; then
        echo "⚠️  Config file is valid but some keys are missing (this may be normal)"
        return 0
    else
        echo "❌ Config file validation failed with $errors error(s)"
        return 1
    fi
}

# Function to get a config value
get_value() {
    local yml_key=""
    local default_value=""
    local use_default=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --default)
                if [ -z "$2" ]; then
                    echo "Error: --default requires a value"
                    echo "Usage: qtools config get-value <yml-key> [--default <value>]"
                    exit 1
                fi
                default_value="$2"
                use_default=true
                shift 2
                ;;
            *)
                if [ -z "$yml_key" ]; then
                    yml_key="$1"
                else
                    echo "Error: Unexpected argument: $1"
                    echo "Usage: qtools config get-value <yml-key> [--default <value>]"
                    exit 1
                fi
                shift
                ;;
        esac
    done

    if [ -z "$yml_key" ]; then
        echo "Error: YAML key is required"
        echo "Usage: qtools config get-value <yml-key> [--default <value>]"
        echo "Example: qtools config get-value service.testnet"
        echo "Example: qtools config get-value service.testnet --default false"
        exit 1
    fi

    # Validate config file first
    if [ ! -f "$QTOOLS_CONFIG_FILE" ]; then
        if [ "$use_default" == "true" ]; then
            echo "$default_value"
            return 0
        fi
        echo "Error: Config file does not exist at: $QTOOLS_CONFIG_FILE"
        exit 1
    fi

    if ! command -v yq >/dev/null 2>&1; then
        if [ "$use_default" == "true" ]; then
            echo "$default_value"
            return 0
        fi
        echo "Error: yq command is not available. Please install yq to read YAML files."
        exit 1
    fi

    # Convert dot notation to yq path (e.g., service.testnet -> .service.testnet)
    local yq_path=".$yml_key"

    # Try to get the value
    local value=$(yq eval "$yq_path" "$QTOOLS_CONFIG_FILE" 2>/dev/null)
    local exit_code=$?

    if [ $exit_code -ne 0 ]; then
        if [ "$use_default" == "true" ]; then
            echo "$default_value"
            return 0
        fi
        echo "Error: Failed to read config key '$yml_key'"
        echo "The key may not exist or the config file may be invalid."
        exit 1
    fi

    # Check if value is null (key doesn't exist)
    # Note: Empty strings are valid values, so we only check for "null"
    if [ "$value" == "null" ]; then
        if [ "$use_default" == "true" ]; then
            echo "$default_value"
            return 0
        fi
        echo "Warning: Config key '$yml_key' is not set"
        exit 1
    fi

    echo "$value"
}

# Function to set a config value
set_value() {
    local yml_key=""
    local value=""
    local quiet=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --quiet|-q)
                quiet=true
                shift
                ;;
            *)
                if [ -z "$yml_key" ]; then
                    yml_key="$1"
                else
                    if [ -z "$value" ]; then
                        value="$1"
                    else
                        value="$value $1"
                    fi
                fi
                shift
                ;;
        esac
    done

    if [ -z "$yml_key" ]; then
        echo "Error: YAML key is required"
        echo "Usage: qtools config set-value <yml-key> <value> [--quiet]"
        echo "Example: qtools config set-value service.testnet true"
        exit 1
    fi

    if [ -z "$value" ]; then
        echo "Error: Value is required"
        echo "Usage: qtools config set-value <yml-key> <value> [--quiet]"
        echo "Example: qtools config set-value service.testnet true"
        exit 1
    fi

    # Validate config file first
    if [ ! -f "$QTOOLS_CONFIG_FILE" ]; then
        echo "Error: Config file does not exist at: $QTOOLS_CONFIG_FILE"
        exit 1
    fi

    if ! command -v yq >/dev/null 2>&1; then
        echo "Error: yq command is not available. Please install yq to modify YAML files."
        exit 1
    fi

    # Validate YAML before modifying
    if ! yq eval '.' "$QTOOLS_CONFIG_FILE" >/dev/null 2>&1; then
        echo "Error: Config file contains invalid YAML. Please fix it before making changes."
        exit 1
    fi

    # Convert dot notation to yq path (e.g., service.testnet -> .service.testnet)
    local yq_path=".$yml_key"

    # Get the old value for display
    local old_value=$(yq eval "$yq_path" "$QTOOLS_CONFIG_FILE" 2>/dev/null)

    # Set the value using yq
    # Use eval -i to modify in place
    # Quote the value to handle strings properly, but allow yq to interpret booleans/numbers
    if yq eval -i "$yq_path = \"$value\"" "$QTOOLS_CONFIG_FILE" 2>/dev/null; then
        # Verify the change was made
        local new_value=$(yq eval "$yq_path" "$QTOOLS_CONFIG_FILE" 2>/dev/null)

        if [ "$quiet" != "true" ]; then
            echo "✓ Configuration updated successfully"
            echo "  Key: $yml_key"
            if [ "$old_value" != "null" ] && [ -n "$old_value" ]; then
                echo "  Old value: $old_value"
            else
                echo "  Old value: (not set)"
            fi
            echo "  New value: $new_value"
            echo ""
            echo "Note: You may need to restart services for changes to take effect."
        fi
    else
        echo "Error: Failed to set config key '$yml_key'"
        echo "The key path may be invalid or the config file may be corrupted."
        exit 1
    fi
}

# Main command handler
case "$1" in
    get-value)
        shift
        get_value "$@"
        ;;
    set-value)
        shift
        set_value "$@"
        ;;
    validate)
        validate_config
        ;;
    help|--help|-h)
        usage
        ;;
    "")
        echo "Error: Command is required"
        echo ""
        usage
        ;;
    *)
        echo "Error: Unknown command '$1'"
        echo ""
        usage
        ;;
esac
