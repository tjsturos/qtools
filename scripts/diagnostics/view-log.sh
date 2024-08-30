#!/bin/bash

# HELP: Views the logs for the node application.

if [ -z "$QUIL_LOG_FILE" ]; then
    echo "Error: QUIL_LOG_FILE is not set"
    exit 1
fi

if [ ! -f "$QUIL_LOG_FILE" ]; then
    echo "Error: Log file not found at $QUIL_LOG_FILE"
    exit 1
fi

# Use tail to follow the log file
tail -f "$QUIL_LOG_FILE"

