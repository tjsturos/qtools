#!/bin/bash

echo "Checking service status..."

if systemctl is-active --quiet "$QUIL_SERVICE_NAME"; then
    echo "$QUIL_SERVICE_NAME is running."
else
    echo "ERROR: $QUIL_SERVICE_NAME is not running." >&2
    exit 1
fi

echo "Service status check completed."