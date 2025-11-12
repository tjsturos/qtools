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
# Fallback if zero or invalid
if ! [[ "$STREAM_PORT" =~ ^[0-9]+$ ]] || [ "$STREAM_PORT" -eq 0 ] 2>/dev/null; then
    STREAM_PORT=8340
fi
sudo ufw allow "$STREAM_PORT"

# Determine worker base ports with sensible defaults per 2.1
BASE_P2P_PORT=$(yq eval '.engine.dataWorkerBaseP2PPort // ""' "$QUIL_CONFIG_FILE")
if [ -z "$BASE_P2P_PORT" ] || [ "$BASE_P2P_PORT" = "0" ]; then
  BASE_P2P_PORT=$(yq eval '.service.clustering.worker_base_p2p_port // "50000"' "$QTOOLS_CONFIG_FILE")
fi
BASE_STREAM_PORT=$(yq eval '.engine.dataWorkerBaseStreamPort // ""' "$QUIL_CONFIG_FILE")
if [ -z "$BASE_STREAM_PORT" ] || [ "$BASE_STREAM_PORT" = "0" ]; then
  BASE_STREAM_PORT=$(yq eval '.service.clustering.worker_base_stream_port // "60000"' "$QTOOLS_CONFIG_FILE")
fi
# Fallback to defaults if zero or invalid
if ! [[ "$BASE_P2P_PORT" =~ ^[0-9]+$ ]] || [ "$BASE_P2P_PORT" -eq 0 ] 2>/dev/null; then
    BASE_P2P_PORT=50000
fi
if ! [[ "$BASE_STREAM_PORT" =~ ^[0-9]+$ ]] || [ "$BASE_STREAM_PORT" -eq 0 ] 2>/dev/null; then
    BASE_STREAM_PORT=60000
fi

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
    END_P2P_PORT=$((BASE_P2P_PORT + WORKER_COUNT - 1))
    END_STREAM_PORT=$((BASE_STREAM_PORT + WORKER_COUNT - 1))
    sudo ufw allow ${BASE_P2P_PORT}:${END_P2P_PORT}/tcp
    sudo ufw allow ${BASE_STREAM_PORT}:${END_STREAM_PORT}/tcp
fi

# Block RFC1918 private address ranges
sudo ufw deny out to 10.0.0.0/8
sudo ufw deny out to 172.16.0.0/12

# Check if we should skip the 192.168 block (for localhost/local_only networks)
SKIP_192_168_BLOCK=$(yq eval '.ssh.skip_192_168_block // false' $QTOOLS_CONFIG_FILE)
LOCAL_ONLY=$(yq eval '.service.clustering.local_only // false' $QTOOLS_CONFIG_FILE)

# Skip 192.168 block if explicitly set or if local_only is enabled
if [ "$SKIP_192_168_BLOCK" != "true" ] && [ "$LOCAL_ONLY" != "true" ]; then
    sudo ufw deny out to 192.168.0.0/16
fi

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
required_ranges=()
if [ "$WORKER_COUNT" -gt 0 ] 2>/dev/null; then
  END_P2P_PORT=$((BASE_P2P_PORT + WORKER_COUNT - 1))
  END_STREAM_PORT=$((BASE_STREAM_PORT + WORKER_COUNT - 1))
  required_ranges+=("${BASE_P2P_PORT}:${END_P2P_PORT}")
  required_ranges+=("${BASE_STREAM_PORT}:${END_STREAM_PORT}")
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

# Check each required range (format-agnostic)
missing_ranges=()
for range in "${required_ranges[@]}"; do
  if ! echo "$actual_output" | grep -E "(^|[^0-9])${range}(/tcp)?\\s+ALLOW" >/dev/null; then
    missing_ranges+=("$range")
  fi
done

# Report results
if [ ${#missing_ports[@]} -eq 0 ] && [ ${#missing_ranges[@]} -eq 0 ]; then
  log "All expected rules are present in the UFW status."
else
  log "The following expected rules are missing in the UFW status:"
  if [ ${#missing_ports[@]} -gt 0 ]; then
    for port in "${missing_ports[@]}"; do
      log "Port $port (ALLOW)"
    done
  fi
  if [ ${#missing_ranges[@]} -gt 0 ]; then
    for range in "${missing_ranges[@]}"; do
      log "Port range $range (ALLOW)"
    done
  fi
  exit 1
fi
