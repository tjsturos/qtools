#!/bin/bash
# HELP: Enables custom logging configuration for the node with separated, rotated, and compressed logs
# PARAM: --path <path>: Log directory path (default: .logs)
# PARAM: --max-size <int>: Maximum log file size in MB (default: 50)
# PARAM: --max-backups <int>: Maximum number of backup files to keep (default: 5)
# PARAM: --max-age <int>: Maximum age in days before deleting old logs (default: 10)
# PARAM: --compress <true|false>: Enable compression of rotated logs (default: true)
# PARAM: --disable: Remove custom logging configuration to use stdout logging
# Usage: qtools enable-custom-logging
# Usage: qtools enable-custom-logging --path /var/log/node --max-size 100
# Usage: qtools enable-custom-logging --disable

# Default values
LOG_PATH=".logs"
MAX_SIZE=50
MAX_BACKUPS=5
MAX_AGE=10
COMPRESS=true
DISABLE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --path)
            LOG_PATH="$2"
            shift 2
            ;;
        --max-size)
            MAX_SIZE="$2"
            shift 2
            ;;
        --max-backups)
            MAX_BACKUPS="$2"
            shift 2
            ;;
        --max-age)
            MAX_AGE="$2"
            shift 2
            ;;
        --compress)
            COMPRESS="$2"
            shift 2
            ;;
        --disable)
            DISABLE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: qtools enable-custom-logging [--path <path>] [--max-size <int>] [--max-backups <int>] [--max-age <int>] [--compress <true|false>] [--disable]"
            exit 1
            ;;
    esac
done

# Check if config file exists
if [ ! -f "$QUIL_CONFIG_FILE" ]; then
    echo "Error: Config file not found at $QUIL_CONFIG_FILE"
    exit 1
fi

# Check if file is owned by quilibrium user and use sudo if needed
file_owner=$(stat -c '%U' "$QUIL_CONFIG_FILE" 2>/dev/null || stat -f '%Su' "$QUIL_CONFIG_FILE" 2>/dev/null || echo "")
USE_SUDO=false
if [ "$file_owner" == "quilibrium" ] && [ "$(whoami)" != "root" ]; then
    USE_SUDO=true
fi

if [ "$DISABLE" == "true" ]; then
    # Remove the logger configuration
    if [ "$USE_SUDO" == "true" ]; then
        sudo yq -i 'del(.logging)' "$QUIL_CONFIG_FILE"
    else
        yq -i 'del(.logging)' "$QUIL_CONFIG_FILE"
    fi
    echo "Custom logging disabled. Logs will now be output to stdout."
else
    # Validate numeric inputs
    if ! [[ "$MAX_SIZE" =~ ^[0-9]+$ ]]; then
        echo "Error: --max-size must be a positive integer"
        exit 1
    fi
    if ! [[ "$MAX_BACKUPS" =~ ^[0-9]+$ ]]; then
        echo "Error: --max-backups must be a positive integer"
        exit 1
    fi
    if ! [[ "$MAX_AGE" =~ ^[0-9]+$ ]]; then
        echo "Error: --max-age must be a positive integer"
        exit 1
    fi

    # Validate compress value
    if [ "$COMPRESS" != "true" ] && [ "$COMPRESS" != "false" ]; then
        echo "Error: --compress must be 'true' or 'false'"
        exit 1
    fi

    # Add or update the logger configuration
    if [ "$USE_SUDO" == "true" ]; then
        sudo yq -i "
            .logging.path = \"$LOG_PATH\" |
            .logging.maxSize = $MAX_SIZE |
            .logging.maxBackups = $MAX_BACKUPS |
            .logging.maxAge = $MAX_AGE |
            .logging.compress = $COMPRESS
        " "$QUIL_CONFIG_FILE"
    else
        yq -i "
            .logging.path = \"$LOG_PATH\" |
            .logging.maxSize = $MAX_SIZE |
            .logging.maxBackups = $MAX_BACKUPS |
            .logging.maxAge = $MAX_AGE |
            .logging.compress = $COMPRESS
        " "$QUIL_CONFIG_FILE"
    fi

    echo "Custom logging enabled:"
    echo "  Path: $LOG_PATH"
    echo "  Max size: ${MAX_SIZE}MB"
    echo "  Max backups: $MAX_BACKUPS"
    echo "  Max age: ${MAX_AGE} days"
    echo "  Compress: $COMPRESS"
    echo ""
    echo "Log files will be created as:"
    echo "  - master.log (master process)"
    echo "  - worker-1.log, worker-2.log, ... (worker processes)"
    echo "Rotated logs will be named: master-2025-10-22T01-02-32.191.log.gz"
fi
