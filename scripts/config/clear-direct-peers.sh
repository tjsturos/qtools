#!/bin/bash
# HELP: Clear all direct peers from the node's config file

DRY_RUN="false"
WAIT="false"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --wait)
            WAIT="true"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: qtools clear-direct-peers [--dry-run] [--wait]"
            exit 1
            ;;
    esac
done

# Check if QUIL config file exists
if [ ! -f "$QUIL_CONFIG_FILE" ]; then
    echo "Error: QUIL config file not found at $QUIL_CONFIG_FILE"
    exit 1
fi

# Get current direct peers count for display
CURRENT_PEERS=$(yq eval '.p2p.directPeers | length' "$QUIL_CONFIG_FILE" 2>/dev/null || echo "0")

# Clear direct peers
if [ "$DRY_RUN" == "true" ]; then
    echo "[DRY RUN] Would clear all direct peers (currently $CURRENT_PEERS peer(s)):"
    echo "  p2p.directPeers = []"
else
    if [ "$CURRENT_PEERS" == "0" ]; then
        echo "No direct peers found in config. Nothing to clear."
        exit 0
    fi

    echo "Clearing all direct peers (removing $CURRENT_PEERS peer(s))..."
    yq eval -i '.p2p.directPeers = []' "$QUIL_CONFIG_FILE"

    if [ "$WAIT" == "true" ]; then
        echo -e "${BLUE}${INFO_ICON} Waiting for next proof submission or workers to be available...${RESET}"
        while read -r line; do
            if [[ $line =~ "submitting data proof" ]] || [[ $line =~ "workers not yet available for proving" ]]; then
                echo -e "${GREEN}${CHECK_ICON} Proof submission detected or workers not available, proceeding with restart${RESET}"
                break
            fi
        done < <(journalctl -u $QUIL_SERVICE_NAME -f -n 0)
    fi

    echo "Direct peers cleared successfully."
    echo "Restarting service to apply changes..."
    qtools restart
fi

