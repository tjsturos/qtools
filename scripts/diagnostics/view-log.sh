#!/bin/bash
IS_DEBUG="${1:-false}"

if [ "$IS_DEBUG" != "false" ]; then
    sudo journalctl -u $QUIL_DEBUG_SERVICE_NAME -f --no-hostname -o cat
else
    sudo journalctl -u $QUIL_SERVICE_NAME -f --no-hostname -o cat
fi