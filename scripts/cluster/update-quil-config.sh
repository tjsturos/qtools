#!/bin/bash

# Exit on error
set -e
source $QTOOLS_PATH/scripts/cluster/utils.sh
# Check if this is a master node
if [ "$(is_master)" != "true" ]; then
    echo -e "${BLUE}${INFO_ICON} This node is not a master node. Skipping Quil config update.${RESET}"
    exit 0
fi

# Parse command line arguments
DRY_RUN=false

# Function to display usage information
usage() {
    echo "Usage: $0 [--dry-run]"
    echo "  --help     Display this help message"
    echo "  --dry-run  Dry run mode (default: false)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            usage
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

if [ "$DRY_RUN" == "true" ]; then
    echo -e "${BLUE}${INFO_ICON} [DRY RUN] Running in dry run mode, no changes will be made${RESET}"
fi

# Run the update_quil_config function
update_quil_config

if [ "$DRY_RUN" == "false" ]; then
    echo -e "${GREEN}${CHECK_ICON} Quil config update completed.${RESET}"
fi 