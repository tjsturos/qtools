#!/bin/bash
# HELP: Monitors the public IP address and logs changes when detected
# Usage: qtools monitor-public-ip

# Get current public IP
CURRENT_IP=$(get_public_ip)

# Validate that we got an IP address
if [ -z "$CURRENT_IP" ]; then
    log "Error: Failed to retrieve public IP address"
    exit 1
fi

# Get previous IP from config
PREVIOUS_IP=$(yq eval '.scheduled_tasks.public_ip.previous_ip // ""' $QTOOLS_CONFIG_FILE)

# If previous IP is empty or null, this is the first run - just store the current IP
if [ -z "$PREVIOUS_IP" ] || [ "$PREVIOUS_IP" == "null" ]; then
    # Store current IP as previous for next run
    yq eval -i ".scheduled_tasks.public_ip.previous_ip = \"$CURRENT_IP\"" "$QTOOLS_CONFIG_FILE"
    exit 0
fi

# Compare current IP with previous IP
if [ "$CURRENT_IP" != "$PREVIOUS_IP" ]; then
    # IP has changed - log the change
    log "Public IP updated from $PREVIOUS_IP to $CURRENT_IP"

    # Store the new IP as previous for next run
    yq eval -i ".scheduled_tasks.public_ip.previous_ip = \"$CURRENT_IP\"" "$QTOOLS_CONFIG_FILE"
else
    # IP hasn't changed - no action needed
    exit 0
fi
