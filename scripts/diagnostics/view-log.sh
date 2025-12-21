#!/bin/bash

# HELP: Views the logs for the node application.

IS_CLUSTERING_ENABLED="$(yq '.service.clustering.enabled' $QTOOLS_CONFIG_FILE)"
FILTER_TEXT=""
EXCLUDE_TEXT=""
CORE_ID=false
LINES=""

# Check if logger config exists
LOGGER_CONFIG=$(yq '.logger' $QUIL_CONFIG_FILE 2>/dev/null)
echo "LOGGER_CONFIG: $LOGGER_CONFIG"
USE_FILE_LOGS=false

if [ "$LOGGER_CONFIG" != "null" ] && [ -n "$LOGGER_CONFIG" ]; then
    echo "Logger config found: $LOGGER_CONFIG"
    USE_FILE_LOGS=true
    # Get logger path, default to .logs
    LOG_PATH=$(yq '.logger.path // ".logs"' $QUIL_CONFIG_FILE)
    # Resolve relative path to absolute path within QUIL_NODE_PATH
    if [[ "$LOG_PATH" != /* ]]; then
        LOG_DIR="$QUIL_NODE_PATH/$LOG_PATH"
    else
        LOG_DIR="$LOG_PATH"
    fi
else
    echo "No logger config found, using journalctl"
fi



# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --core|--worker)
            if [[ -n $2 && $2 =~ ^[0-9]+$ ]]; then
                CORE_ID=$2
                shift 2
            else
                echo "Error: $1 option requires a valid numeric core/worker ID"
                exit 1
            fi
            ;;
        -n)
            LINES=$2
            shift 2
            ;;
        --filter|--grep)
            FILTER_TEXT=$2
            shift 2
            ;;
        --exclude)
            EXCLUDE_TEXT=$2
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# If using file logs, read from log files
if [ "$USE_FILE_LOGS" == "true" ]; then
    MAX_CORES=$(nproc)

    # Determine which log file to read
    if [ "$CORE_ID" != "false" ]; then
        # Validate core/worker ID
        if [ "$CORE_ID" -lt 1 ] || [ "$CORE_ID" -gt "$MAX_CORES" ]; then
            echo "Error: Core/worker ID must be between 1 and $MAX_CORES"
            exit 1
        fi
        LOG_FILE="$LOG_DIR/worker-$CORE_ID.log"
        echo "Viewing logs for worker $CORE_ID:"
    else
        LOG_FILE="$LOG_DIR/master.log"
    fi

    # Check if log file exists
    if [ ! -f "$LOG_FILE" ]; then
        # File might exist but be owned by quilibrium - check with sudo
        if ! sudo test -f "$LOG_FILE" 2>/dev/null; then
            echo "Error: Log file not found: $LOG_FILE"
            exit 1
        fi
    fi

    # Set permissions to u=rwx,g=rwx,o=r (774) so qtools group can read without sudo
    # Use sudo to change permissions since file is owned by quilibrium
    if [ -f "$LOG_FILE" ] || sudo test -f "$LOG_FILE" 2>/dev/null; then
        sudo chmod u=rwx,g=rwx,o=r "$LOG_FILE" 2>/dev/null || true
    fi

    # Build tail command - show last N lines then follow (like journalctl)
    # Build grep pipeline for filtering/excluding
    GREP_PIPELINE=""
    if [ -n "$FILTER_TEXT" ]; then
        GREP_PIPELINE="grep --color=always \"$FILTER_TEXT\""
    fi
    if [ -n "$EXCLUDE_TEXT" ]; then
        if [ -n "$GREP_PIPELINE" ]; then
            GREP_PIPELINE="$GREP_PIPELINE | grep -E -v --color=always \"$EXCLUDE_TEXT\""
        else
            GREP_PIPELINE="grep -E -v --color=always \"$EXCLUDE_TEXT\""
        fi
    fi

    if [ -n "$LINES" ]; then
        # Show last N lines, then follow
        if [ -n "$GREP_PIPELINE" ]; then
            tail -n "$LINES" -f "$LOG_FILE" | eval "$GREP_PIPELINE"
        else
            tail -n "$LINES" -f "$LOG_FILE"
        fi
    else
        # Follow logs from end
        if [ -n "$GREP_PIPELINE" ]; then
            tail -f "$LOG_FILE" | eval "$GREP_PIPELINE"
        else
            tail -f "$LOG_FILE"
        fi
    fi
    exit 0
fi

# Fall back to journalctl if logger config is not set
# Build journalctl command with optional filtering and excluding
if [ "$IS_CLUSTERING_ENABLED" == "true" ]; then
    if [ "$CORE_ID" == "false" ]; then
        if [ -n "$EXCLUDE_TEXT" ]; then
            sudo journalctl -u $QUIL_SERVICE_NAME -f --no-hostname -o cat ${FILTER_TEXT:+--grep="$FILTER_TEXT"} ${LINES:+-n $LINES} | grep -E -v --color=always "$EXCLUDE_TEXT"
        else
            sudo journalctl -u $QUIL_SERVICE_NAME -f --no-hostname -o cat ${FILTER_TEXT:+--grep="$FILTER_TEXT"} ${LINES:+-n $LINES}
        fi
    else
        if [ -n "$EXCLUDE_TEXT" ]; then
            sudo journalctl -u $QUIL_DATA_WORKER_SERVICE_NAME@$CORE_ID -f --no-hostname -o cat ${FILTER_TEXT:+--grep="$FILTER_TEXT"} ${LINES:+-n $LINES} | grep -E -v --color=always "$EXCLUDE_TEXT"
        else
            sudo journalctl -u $QUIL_DATA_WORKER_SERVICE_NAME@$CORE_ID -f --no-hostname -o cat ${FILTER_TEXT:+--grep="$FILTER_TEXT"} ${LINES:+-n $LINES}
        fi
    fi
else
    if [ -n "$EXCLUDE_TEXT" ]; then
        sudo journalctl -u $QUIL_SERVICE_NAME -f --no-hostname -o cat ${FILTER_TEXT:+--grep="$FILTER_TEXT"} ${LINES:+-n $LINES} | grep -E -v --color=always "$EXCLUDE_TEXT"
    else
        sudo journalctl -u $QUIL_SERVICE_NAME -f --no-hostname -o cat ${FILTER_TEXT:+--grep="$FILTER_TEXT"} ${LINES:+-n $LINES}
    fi
fi
