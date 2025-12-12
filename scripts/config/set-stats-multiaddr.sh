#!/bin/bash
# HELP: Set the stats multiaddr in the node's config file.
# PARAM: --enable - Enable stats reporting
# PARAM: --disable - Disable stats reporting
# PARAM: --url <url> - The stats URL (required if --enable is used)

ENABLE=""
DISABLE=""
URL=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --enable)
            ENABLE="true"
            shift
            ;;
        --disable)
            DISABLE="true"
            shift
            ;;
        --url)
            if [[ -n "$2" ]]; then
                URL="$2"
                shift 2
            else
                echo "Error: --url requires a URL"
                exit 1
            fi
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: qtools set-stats-multiaddr --enable --url <url> | --disable"
            exit 1
            ;;
    esac
done

# Validate parameters
if [ "$ENABLE" = "true" ] && [ "$DISABLE" = "true" ]; then
    echo "Error: Cannot use both --enable and --disable"
    exit 1
fi

if [ -z "$ENABLE" ] && [ -z "$DISABLE" ]; then
    echo "Error: Must specify either --enable or --disable"
    echo "Usage: qtools set-stats-multiaddr --enable --url <url> | --disable"
    exit 1
fi

# Check if QUIL config file exists
if [ ! -f "$QUIL_CONFIG_FILE" ]; then
    echo "Error: QUIL config file not found at $QUIL_CONFIG_FILE"
    exit 1
fi

# Determine stats multiaddr value
if [ "$DISABLE" = "true" ]; then
    STATS_MULTIADDR=""
elif [ "$ENABLE" = "true" ]; then
    if [ -z "$URL" ]; then
        echo "Error: --url is required when using --enable"
        echo "Usage: qtools set-stats-multiaddr --enable --url <url>"
        exit 1
    fi
    # Convert URL to multiaddr format if needed
    # If URL is already a multiaddr, use it as-is
    if [[ "$URL" =~ ^/ ]]; then
        STATS_MULTIADDR="$URL"
    else
        # Assume it's a DNS name, convert to /dns/.../tcp/443 format
        STATS_MULTIADDR="/dns/${URL}/tcp/443"
    fi
fi

# Check if file is owned by quilibrium user and use sudo if needed
# This handles cases where user was just added to quilibrium group
# but current shell session doesn't have group membership active yet
file_owner=$(stat -c '%U' "$QUIL_CONFIG_FILE" 2>/dev/null || stat -f '%Su' "$QUIL_CONFIG_FILE" 2>/dev/null || echo "")
if [ "$file_owner" == "quilibrium" ] && [ "$(whoami)" != "root" ]; then
    sudo yq -i '.engine.statsMultiaddr = "'"$STATS_MULTIADDR"'"' "$QUIL_CONFIG_FILE"
else
    yq -i '.engine.statsMultiaddr = "'"$STATS_MULTIADDR"'"' "$QUIL_CONFIG_FILE"
fi

if [ -z "$STATS_MULTIADDR" ]; then
    echo "Stats multiaddr disabled"
else
    echo "Stats multiaddr updated to: $STATS_MULTIADDR"
fi
