#!/bin/bash
# HELP: Clear announce multiaddrs in QUIL config (reset to empty values)

DRY_RUN="false"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: qtools clear-announce-multiaddrs [--dry-run]"
            exit 1
            ;;
    esac
done

# Check if QUIL config file exists
if [ ! -f "$QUIL_CONFIG_FILE" ]; then
    echo "Error: QUIL config file not found at $QUIL_CONFIG_FILE"
    exit 1
fi

# Clear announce multiaddrs
if [ "$DRY_RUN" == "true" ]; then
    echo "[DRY RUN] Would clear:"
    echo "  p2p.announceListenMultiaddr = \"\""
    echo "  p2p.announceStreamListenMultiaddr = \"\""
    echo "  engine.dataWorkerAnnounceP2PMultiaddrs = []"
    echo "  engine.dataWorkerAnnounceStreamMultiaddrs = []"
else
    echo "Clearing announce multiaddrs..."

    # Clear master announce multiaddrs
    yq eval -i '.p2p.announceListenMultiaddr = ""' "$QUIL_CONFIG_FILE"
    yq eval -i '.p2p.announceStreamListenMultiaddr = ""' "$QUIL_CONFIG_FILE"

    # Clear worker announce arrays
    yq eval -i '.engine.dataWorkerAnnounceP2PMultiaddrs = []' "$QUIL_CONFIG_FILE"
    yq eval -i '.engine.dataWorkerAnnounceStreamMultiaddrs = []' "$QUIL_CONFIG_FILE"

    echo "Announce multiaddrs cleared successfully."
    echo "Restarting service to apply changes..."
    qtools restart
fi

