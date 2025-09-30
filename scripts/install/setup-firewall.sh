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

# Read Quil node config for 2.1 worker/master stream requirements
STREAM_MULTIADDR=$(yq eval '.p2p.streamListenMultiaddr // ""' "$QUIL_CONFIG_FILE")
# Extract tcp port from multiaddr, fallback to 8340 per docs
STREAM_PORT=$(echo "$STREAM_MULTIADDR" | sed -n 's#.*/tcp/\([0-9]\+\).*#\1#p')
[ -z "$STREAM_PORT" ] && STREAM_PORT=8340
sudo ufw allow "$STREAM_PORT"

# Determine worker base ports with sensible defaults per 2.1
BASE_P2P_PORT=$(yq eval '.engine.dataWorkerBaseP2PPort // "50000"' "$QUIL_CONFIG_FILE")
BASE_STREAM_PORT=$(yq eval '.engine.dataWorkerBaseStreamPort // "60000"' "$QUIL_CONFIG_FILE")

echo "BASE_P2P_PORT: $BASE_P2P_PORT"
echo "BASE_STREAM_PORT: $BASE_STREAM_PORT"

echo "STREAM_PORT: $STREAM_PORT"

# Determine worker count from config; fallback to vCPU count
WORKER_COUNT=$(yq eval '.engine.dataWorkerP2PMultiaddrs | length' "$QUIL_CONFIG_FILE" 2>/dev/null)
if [ -z "$WORKER_COUNT" ] || [ "$WORKER_COUNT" = "null" ] || [ "$WORKER_COUNT" -eq 0 ] 2>/dev/null; then
    WORKER_COUNT=$(yq eval '.engine.dataWorkerStreamMultiaddrs | length' "$QUIL_CONFIG_FILE" 2>/dev/null)
fi
if [ -z "$WORKER_COUNT" ] || [ "$WORKER_COUNT" = "null" ] || [ "$WORKER_COUNT" -eq 0 ] 2>/dev/null; then
    WORKER_COUNT=$(nproc)
fi

# Open P2P and stream ports for each worker
if [ "$WORKER_COUNT" -gt 0 ] 2>/dev/null; then
    for ((i=0; i<WORKER_COUNT; i++)); do
        sudo ufw allow $((BASE_P2P_PORT + i))
        sudo ufw allow $((BASE_STREAM_PORT + i))
    done
fi

# Block RFC1918 private address ranges
sudo ufw deny out to 10.0.0.0/8
sudo ufw deny out to 172.16.0.0/12
sudo ufw deny out to 192.168.0.0/16

# Block multicast
sudo ufw deny out to 224.0.0.0/4

# Block broadcast
sudo ufw deny out to 255.255.255.255

required_ports=(
  "$SSH_PORT"
  "8336"
  "$STREAM_PORT"
)

# Include worker P2P/stream ranges in verification
if [ "$WORKER_COUNT" -gt 0 ] 2>/dev/null; then
  for ((i=0; i<WORKER_COUNT; i++)); do
    required_ports+=("$((BASE_P2P_PORT + i))")
    required_ports+=("$((BASE_STREAM_PORT + i))")
  done
fi

# Get the actual output of 'ufw status'
actual_output=$(sudo ufw status)

# Check if UFW is active
if ! echo "$actual_output" | grep -q "Status: active"; then
  log "UFW is not active."
  exit 1
fi

# Check each required port (format-agnostic)
missing_ports=()
for port in "${required_ports[@]}"; do
  if ! echo "$actual_output" | grep -E "(^|[^0-9])${port}(/tcp)?\\s+ALLOW" >/dev/null; then
    missing_ports+=("$port")
  fi
done

# Report results
if [ ${#missing_ports[@]} -eq 0 ]; then
  log "All expected rules are present in the UFW status."
else
  log "The following expected rules are missing in the UFW status:"
  for port in "${missing_ports[@]}"; do
    log "Port $port (ALLOW)"
  done
  exit 1
fi
