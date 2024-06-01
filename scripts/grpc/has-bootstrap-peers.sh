#!/bin/bash


PEERS="$(grpcurl -plaintext -max-msg-sz 5000000 localhost:8337 quilibrium.node.node.pb.NodeService.GetPeerInfo | jq '.peerInfo | length')"

CONFIG_FILE=$QUIL_NODE_PATH/.config/config.yml
base64_to_base58() {
  local base64_input=$1
  echo "$base64_input" | base64 --decode | base58
}

# Extract peerIds from JSON
peer_ids=$(echo "$PEERS" | jq -r '.peerInfo[].peerId')

# Extract Qm... parts from YAML
bootstrap_peer_ids=$(grep -oP '/p2p/\KQm\w+' "$CONFIG_FILE")

# Decode peerIds from base64 to base58
transformed_peer_ids=()
for peer_id in $peer_ids; do
  transformed_peer_ids+=($(base64_to_base58 "$peer_id"))
done

BOOTSTRAP_PEER_COUNT=0
for transformed_peer_id in "${transformed_peer_ids[@]}"; do
  for bootstrap_peer_id in $bootstrap_peer_ids; do
    if [[ "$transformed_peer_id" == "$bootstrap_peer_id" ]]; then
      ((BOOTSTRAP_PEER_COUNT++))
    fi
  done
done
# Check if the length is greater than 0
if [ "$BOOTSTRAP_PEER_COUNT" -gt 0 ]; then
    log "Peer info length is greater than 0 ($BOOTSTRAP_PEER_COUNT). Doing nothing."
else
    # Prompt for reboot with a default to no and a timeout of 10 seconds
    read -t 10 -p "Peer info length is 0. Do you want to reboot? (y/N): " ANSWER
    ANSWER=${ANSWER:-N}

    if [[ "$ANSWER" =~ ^[Yy]$ ]]; then
        echo "Rebooting..."
        sudo reboot
    else
        echo "Not going for a reboot."
    fi
fi