#!/bin/bash

PEER_COUNT="$(grpcurl -plaintext -max-msg-sz 5000000 localhost:8337 quilibrium.node.node.pb.NodeService.GetPeerInfo | jq '.peerInfo | length')"

# Check if the length is greater than 0
if [ "$PEER_COUNT" -gt 0 ]; then
    log "Peer info length is greater than 0 ($PEER_COUNT). Doing nothing."
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