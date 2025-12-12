#!/bin/bash

# Parse command line arguments
if [ $# -eq 0 ]; then
    echo "Usage: qtools set-internal-ip <ip>"
    exit 1
fi

IP="$1"

# Validate IP address format
if ! [[ $IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Invalid IP address format. Please use format: xxx.xxx.xxx.xxx"
    exit 1
fi

# Update the internal_ip setting in config
qtools config set-value settings.internal_ip "$IP" --quiet

echo "Internal IP updated successfully to: $IP"
