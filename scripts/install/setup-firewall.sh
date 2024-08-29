#!/bin/bash
# HELP: Sets up the firewall to enable ports 22 (ssh), 8336 (other nodes), and 443 (general encrypted traffic).

log "Setting up firewall"

# macOS uses pf (Packet Filter) for firewall
# We'll need to modify /etc/pf.conf to add our rules

TEMP_PF_CONF="/tmp/pf.conf"
PF_CONF="/etc/pf.conf"

# Backup the original pf.conf
sudo cp $PF_CONF ${PF_CONF}.bak

# Add our rules to the temporary file
cat $PF_CONF > $TEMP_PF_CONF
echo "pass in proto tcp from any to any port {22 8336 443}" >> $TEMP_PF_CONF

# Replace the original file with our modified version
sudo mv $TEMP_PF_CONF $PF_CONF

# Reload pf with the new configuration
sudo pfctl -f $PF_CONF

log "Firewall setup complete"
