#!/bin/bash
# HELP: Sets up the firewall to enable ports 22 (ssh), 8336 (other nodes), and 443 (general encrypted traffic).

log "Setting up firewall"

# Disable IPv6 in UFW when adding new rules
if [ -f /etc/default/ufw ]; then
    sudo sed -i 's/IPV6=yes/IPV6=no/' /etc/default/ufw
fi

echo "y" | sudo ufw enable

SSH_PORT=$(yq eval '.ssh.port //22' $QTOOLS_CONFIG_FILE)
SSH_FROM_IP=$(yq eval '.ssh.allow_from_ip' $QTOOLS_CONFIG_FILE)

if [ "$SSH_FROM_IP" != "false" ]; then
    qtools set-ssh-port-from-ip
else
    sudo ufw allow $SSH_PORT
fi

LISTEN_ADDR=$(yq eval '.settings.listenAddr.port' $QTOOLS_CONFIG_FILE)
sudo ufw allow 8336

# Block RFC1918 private address ranges
sudo ufw deny out to 10.0.0.0/8
sudo ufw deny out to 172.16.0.0/12
sudo ufw deny out to 192.168.0.0/16

# Block multicast
sudo ufw deny out to 224.0.0.0/4

# Block broadcast
sudo ufw deny out to 255.255.255.255

expected_rules=(
  "22                         ALLOW       Anywhere"
  "8336                       ALLOW       Anywhere"
)

# Get the actual output of 'ufw status'
actual_output=$(sudo ufw status)

# Check if UFW is active
if ! echo "$actual_output" | grep -q "Status: active"; then
  log "UFW is not active."
  exit 1
fi

# Check each expected rule
missing_rules=()
for rule in "${expected_rules[@]}"; do
  if ! echo "$actual_output" | grep -q "$rule"; then
    missing_rules+=("$rule")
  fi
done

# Report results
if [ ${#missing_rules[@]} -eq 0 ]; then
  log "All expected rules are present in the UFW status."
else
  log "The following expected rules are missing in the UFW status:"
  for rule in "${missing_rules[@]}"; do
    log "$rule"
  done
  exit 1
fi
