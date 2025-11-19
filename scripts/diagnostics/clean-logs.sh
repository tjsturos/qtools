#!/bin/bash

# HELP: Cleans log files for qtools and the node application.
# PARAM: --journal: Also clean systemd journal logs
# PARAM: --errors: Also clean diagnostic error logs
# PARAM: --all: Clean all logs (qtools log, journal, and error logs)

CLEAN_JOURNAL=false
CLEAN_ERRORS=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --journal)
            CLEAN_JOURNAL=true
            ;;
        --errors)
            CLEAN_ERRORS=true
            ;;
        --all)
            CLEAN_JOURNAL=true
            CLEAN_ERRORS=true
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: qtools clean-logs [--journal] [--errors] [--all]"
            exit 1
            ;;
    esac
    shift
done

# Get the log file path from config
LOG_OUTPUT_FILE=$(yq '.settings.log_file // "debug.log"' $QTOOLS_CONFIG_FILE)
LOG_FILE_PATH="$QTOOLS_PATH/$LOG_OUTPUT_FILE"

# Clean main qtools log file
if [ -f "$LOG_FILE_PATH" ]; then
    > "$LOG_FILE_PATH"
    echo "Cleaned qtools log file: $LOG_FILE_PATH"
else
    echo "Qtools log file not found: $LOG_FILE_PATH"
fi

# Clean systemd journal logs if requested
if [ "$CLEAN_JOURNAL" == "true" ]; then
    sudo journalctl --vacuum-time=1s -u "$QUIL_SERVICE_NAME" > /dev/null 2>&1

    # Also clean data worker logs if clustering is enabled
    if [ "$IS_CLUSTERING_ENABLED" == "true" ]; then
        sudo journalctl --vacuum-time=1s -u "$QUIL_DATA_WORKER_SERVICE_NAME@*" > /dev/null 2>&1
    fi

    echo "Cleaned systemd journal logs"
fi

# Clean diagnostic error logs if requested
if [ "$CLEAN_ERRORS" == "true" ]; then
    ERROR_LOG_DIR="$QTOOLS_PATH/errors"
    if [ -d "$ERROR_LOG_DIR" ]; then
        rm -f "$ERROR_LOG_DIR"/*.txt 2>/dev/null
        echo "Cleaned diagnostic error logs in: $ERROR_LOG_DIR"
    else
        echo "Diagnostic error log directory not found: $ERROR_LOG_DIR"
    fi
fi

echo "Log cleaning completed."

