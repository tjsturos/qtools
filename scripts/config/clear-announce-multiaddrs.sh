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

# Check if QUIL config file exists (handle quilibrium-owned files)
if ! safe_file_exists "$QUIL_CONFIG_FILE"; then
    echo "Error: QUIL config file not found at $QUIL_CONFIG_FILE"
    exit 1
fi

# Check if file is owned by quilibrium user and use sudo if needed
file_owner=$(stat -c '%U' "$QUIL_CONFIG_FILE" 2>/dev/null || sudo stat -c '%U' "$QUIL_CONFIG_FILE" 2>/dev/null || stat -f '%Su' "$QUIL_CONFIG_FILE" 2>/dev/null || echo "")
use_sudo=false
if [ "$file_owner" == "quilibrium" ] && [ "$(whoami)" != "root" ]; then
    use_sudo=true
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
    if [ "$use_sudo" == "true" ]; then
        sudo yq eval -i '.p2p.announceListenMultiaddr = ""' "$QUIL_CONFIG_FILE"
        sudo yq eval -i '.p2p.announceStreamListenMultiaddr = ""' "$QUIL_CONFIG_FILE"
        # Clear worker announce arrays
        sudo yq eval -i '.engine.dataWorkerAnnounceP2PMultiaddrs = []' "$QUIL_CONFIG_FILE"
        sudo yq eval -i '.engine.dataWorkerAnnounceStreamMultiaddrs = []' "$QUIL_CONFIG_FILE"
    else
        yq eval -i '.p2p.announceListenMultiaddr = ""' "$QUIL_CONFIG_FILE"
        yq eval -i '.p2p.announceStreamListenMultiaddr = ""' "$QUIL_CONFIG_FILE"
        # Clear worker announce arrays
        yq eval -i '.engine.dataWorkerAnnounceP2PMultiaddrs = []' "$QUIL_CONFIG_FILE"
        yq eval -i '.engine.dataWorkerAnnounceStreamMultiaddrs = []' "$QUIL_CONFIG_FILE"
    fi

    echo "Announce multiaddrs cleared successfully."
    echo "Restarting service to apply changes..."
    qtools --describe "clear-announce-multiaddrs" restart
fi

