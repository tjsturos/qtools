#!/bin/bash


DRY_RUN="false"
WAIT="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --wait)
            WAIT=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done


# Get publish multiaddr settings from config
SSH_KEY_PATH=$(yq eval '.settings.publish_multiaddr.ssh_key_path' $QTOOLS_CONFIG_FILE)
REMOTE_USER=$(yq eval '.settings.publish_multiaddr.remote_user' $QTOOLS_CONFIG_FILE)
REMOTE_HOST=$(yq eval '.settings.publish_multiaddr.remote_host' $QTOOLS_CONFIG_FILE)
REMOTE_FILE=$(yq eval '.settings.publish_multiaddr.remote_file' $QTOOLS_CONFIG_FILE)

# Pull the remote YAML file
TEMP_FILE=$(mktemp)
scp -i "$SSH_KEY_PATH" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_FILE}" $TEMP_FILE

# Update local config with remote peers
REMOTE_PEERS=$(yq eval '.directPeers[]' $TEMP_FILE)
yq eval -i ".p2p.directPeers = []" $QUIL_CONFIG_FILE

LOCAL_PEER_ID=$(qtools peer-id)
# Add each remote peer to local config, excluding our own multiaddr
for peer in $REMOTE_PEERS; do
    # Extract IP from multiaddr if it exists
    PEER_IP=$(echo $peer | grep -oE '/ip4/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | cut -d'/' -f3)
    if [ ! -z "$PEER_IP" ]; then
        # Check if IP exists in local interfaces
        if ip addr | grep -q "$PEER_IP"; then
            echo "Skipping peer $peer as IP $PEER_IP belongs to local machine"
            continue
        fi
    fi

    # Extract peer ID from multiaddr
    PEER_ID=$(echo $peer | grep -oE '/p2p/[^/]*' | cut -d'/' -f3)
    if [ "$PEER_ID" == "$LOCAL_PEER_ID" ]; then
        echo "Skipping peer $peer as peer ID $PEER_ID matches local peer ID"
        continue
    fi

    echo "Adding peer $peer to local config"
    if [ "$DRY_RUN" == "false" ]; then
        yq eval -i ".p2p.directPeers += [\"$peer\"]" $QUIL_CONFIG_FILE
    fi
    
done

# Cleanup
rm $TEMP_FILE

if [ "$DRY_RUN" == "false" ]; then
    if [ "$WAIT" == "true" ]; then
        echo -e "${BLUE}${INFO_ICON} Waiting for next proof submission or workers to be available...${RESET}"
        while read -r line; do
            if [[ $line =~ "submitting data proof" ]] || [[ $line =~ "workers not yet available for proving" ]]; then
                echo -e "${GREEN}${CHECK_ICON} Proof submission detected or workers not available, proceeding with restart${RESET}"
                break
            fi
        done < <(journalctl -u $QUIL_SERVICE_NAME -f -n 0)
    fi
    qtools restart
fi