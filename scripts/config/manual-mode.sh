#!/bin/bash
# HELP: Enable or disable manual mode for managing workers separately from the master process
# PARAM: --enable: Enable manual mode with optional --cores|--workers flag to specify worker count
# PARAM: --disable: Disable manual mode and clear worker configuration
# Usage: qtools manual-mode --enable
# Usage: qtools manual-mode --enable --cores 4
# Usage: qtools manual-mode --enable --workers 4
# Usage: qtools manual-mode --disable

# Source required utilities
source $QTOOLS_PATH/utils/index.sh

# Check if config file exists
if [ ! -f "$QTOOLS_CONFIG_FILE" ]; then
    echo "Error: Config file not found at $QTOOLS_CONFIG_FILE"
    exit 1
fi

# Check if quil config file exists
if [ ! -f "$QUIL_CONFIG_FILE" ]; then
    echo "Error: Quil config file not found at $QUIL_CONFIG_FILE"
    exit 1
fi

# Function to calculate default worker count based on CPU cores
calculate_default_worker_count() {
    local cores=$(nproc)

    # Legacy calculation logic
    if [ "$cores" -eq 1 ]; then
        echo 1
    elif [ "$cores" -le 4 ]; then
        echo $((cores - 1))
    elif [ "$cores" -le 16 ]; then
        echo $((cores - 2))
    elif [ "$cores" -le 32 ]; then
        echo $((cores - 3))
    elif [ "$cores" -le 64 ]; then
        echo $((cores - 4))
    else
        echo $((cores - 5))
    fi
}

# Function to enable manual mode
enable_manual_mode() {
    local worker_count="$1"

    # Calculate default if not provided
    if [ -z "$worker_count" ]; then
        worker_count=$(calculate_default_worker_count)
        echo "Calculated default worker count: $worker_count"
    fi

    # Validate worker count
    if ! [[ "$worker_count" =~ ^[0-9]+$ ]] || [ "$worker_count" -le 0 ]; then
        echo "Error: Worker count must be a positive integer"
        exit 1
    fi

    # Get local IP
    LOCAL_IP=$(get_local_ip)
    # Fallback to 0.0.0.0 if get_local_ip doesn't return anything (e.g., clustering not enabled)
    if [ -z "$LOCAL_IP" ]; then
        LOCAL_IP="0.0.0.0"
    fi

    # Get base ports from config or use defaults
    local base_p2p=$(yq eval '.engine.dataWorkerBaseP2PPort // "0"' $QUIL_CONFIG_FILE)
    if [ -z "$base_p2p" ] || [ "$base_p2p" = "0" ]; then
        base_p2p=$(yq eval '.service.clustering.worker_base_p2p_port // "50000"' $QTOOLS_CONFIG_FILE)
    fi
    if [ -z "$base_p2p" ] || [ "$base_p2p" = "0" ]; then
        base_p2p=50000
    fi

    local base_stream=$(yq eval '.engine.dataWorkerBaseStreamPort // "0"' $QUIL_CONFIG_FILE)
    if [ -z "$base_stream" ] || [ "$base_stream" = "0" ]; then
        base_stream=$(yq eval '.service.clustering.worker_base_stream_port // "60000"' $QTOOLS_CONFIG_FILE)
    fi
    if [ -z "$base_stream" ] || [ "$base_stream" = "0" ]; then
        base_stream=60000
    fi

    echo "Enabling manual mode with $worker_count workers"
    echo "Base P2P port: $base_p2p"
    echo "Base stream port: $base_stream"

    # Set base ports in quil config
    yq eval -i ".engine.dataWorkerBaseP2PPort = $base_p2p" $QUIL_CONFIG_FILE
    yq eval -i ".engine.dataWorkerBaseStreamPort = $base_stream" $QUIL_CONFIG_FILE

    # Clear existing arrays
    yq eval -i '.engine.dataWorkerP2PMultiaddrs = []' $QUIL_CONFIG_FILE
    yq eval -i '.engine.dataWorkerStreamMultiaddrs = []' $QUIL_CONFIG_FILE

    # Populate worker arrays starting from base port
    for ((i=0; i<$worker_count; i++)); do
        local p2p_port=$((base_p2p + i))
        local stream_port=$((base_stream + i))
        yq eval -i ".engine.dataWorkerP2PMultiaddrs += \"/ip4/${LOCAL_IP:-0.0.0.0}/tcp/$p2p_port\"" $QUIL_CONFIG_FILE
        yq eval -i ".engine.dataWorkerStreamMultiaddrs += \"/ip4/${LOCAL_IP:-0.0.0.0}/tcp/$stream_port\"" $QUIL_CONFIG_FILE
    done

    # Set qtools config for manual mode
    qtools config set-value manual.enabled "true" --quiet
    qtools config set-value manual.worker_count "$worker_count" --quiet
    qtools config set-value manual.local_only "true" --quiet

    # Update firewall rules for worker ports
    update_firewall_rules "$base_p2p" "$base_stream" "$worker_count"

    # Update worker services
    echo "Updating worker services..."
    qtools update-worker-service

    echo "Manual mode enabled with $worker_count workers"
    echo "Workers configured starting from core index 1"
}

# Function to update firewall rules for manual mode workers
update_firewall_rules() {
    local base_p2p=$1
    local base_stream=$2
    local worker_count=$3

    # Check if UFW is enabled
    if ! command -v ufw >/dev/null 2>&1; then
        echo "Warning: UFW not found, skipping firewall rule updates"
        return 0
    fi

    ufw_status=$(sudo ufw status 2>/dev/null | grep -i "Status: active")
    if [ -z "$ufw_status" ]; then
        echo "Warning: UFW is not active, skipping firewall rule updates"
        return 0
    fi

    # Calculate end ports
    local end_p2p=$((base_p2p + worker_count - 1))
    local end_stream=$((base_stream + worker_count - 1))

    # Calculate end ports
    local end_p2p=$((base_p2p + worker_count - 1))
    local end_stream=$((base_stream + worker_count - 1))

    echo "Checking firewall rules for worker ports..."
    echo "P2P ports: $base_p2p-$end_p2p"
    echo "Stream ports: $base_stream-$end_stream"

    # Check if the exact range rules already exist
    local p2p_range_exists=$(sudo ufw status 2>/dev/null | grep -E "${base_p2p}:${end_p2p}/tcp")
    local stream_range_exists=$(sudo ufw status 2>/dev/null | grep -E "${base_stream}:${end_stream}/tcp")

    if [ -n "$p2p_range_exists" ] && [ -n "$stream_range_exists" ]; then
        echo "Firewall rules for worker ports already exist, skipping update"
        return 0
    fi

    echo "Updating firewall rules for worker ports..."

    # Remove any existing rules for the port ranges
    # This includes single-port rules for base ports and any range rules that overlap
    # UFW status format: [N] PORT/tcp or [N] START:END/tcp

    # Remove P2P port rules - match rules that mention base_p2p or end_p2p
    # Pattern matches: base_p2p/tcp, base_p2p:END/tcp, START:end_p2p/tcp, or START:END/tcp where range overlaps
    local p2p_rules_to_delete=$(sudo ufw status numbered 2>/dev/null | grep -E "\[[0-9]+\].*(${base_p2p}(:|/tcp)|:${end_p2p}/tcp|${base_p2p}:${end_p2p}/tcp)" | awk -F'[][]' '{print $2}' | sort -rn | uniq)
    if [ -n "$p2p_rules_to_delete" ]; then
        echo "$p2p_rules_to_delete" | while read -r rule_num; do
            echo "y" | sudo ufw --force delete "$rule_num" >/dev/null 2>&1
        done
    fi

    # Remove stream port rules - match rules that mention base_stream or end_stream
    local stream_rules_to_delete=$(sudo ufw status numbered 2>/dev/null | grep -E "\[[0-9]+\].*(${base_stream}(:|/tcp)|:${end_stream}/tcp|${base_stream}:${end_stream}/tcp)" | awk -F'[][]' '{print $2}' | sort -rn | uniq)
    if [ -n "$stream_rules_to_delete" ]; then
        echo "$stream_rules_to_delete" | while read -r rule_num; do
            echo "y" | sudo ufw --force delete "$rule_num" >/dev/null 2>&1
        done
    fi

    # Add new range rules for worker ports (only if they don't already exist)
    if [ -z "$p2p_range_exists" ]; then
        sudo ufw allow ${base_p2p}:${end_p2p}/tcp >/dev/null 2>&1
        echo "Added firewall rule for P2P ports: ${base_p2p}:${end_p2p}/tcp"
    fi

    if [ -z "$stream_range_exists" ]; then
        sudo ufw allow ${base_stream}:${end_stream}/tcp >/dev/null 2>&1
        echo "Added firewall rule for stream ports: ${base_stream}:${end_stream}/tcp"
    fi

    echo "Firewall rules updated successfully"
}

# Function to remove firewall rules for manual mode workers
remove_firewall_rules() {
    # Get worker count and base ports from config
    local worker_count=$(yq eval '.manual.worker_count // 0' $QTOOLS_CONFIG_FILE)

    if [ "$worker_count" -le 0 ]; then
        return 0
    fi

    # Get base ports from quil config
    local base_p2p=$(yq eval '.engine.dataWorkerBaseP2PPort // "0"' $QUIL_CONFIG_FILE)
    if [ -z "$base_p2p" ] || [ "$base_p2p" = "0" ]; then
        base_p2p=$(yq eval '.service.clustering.worker_base_p2p_port // "50000"' $QTOOLS_CONFIG_FILE)
    fi
    if [ -z "$base_p2p" ] || [ "$base_p2p" = "0" ]; then
        base_p2p=50000
    fi

    local base_stream=$(yq eval '.engine.dataWorkerBaseStreamPort // "0"' $QUIL_CONFIG_FILE)
    if [ -z "$base_stream" ] || [ "$base_stream" = "0" ]; then
        base_stream=$(yq eval '.service.clustering.worker_base_stream_port // "60000"' $QTOOLS_CONFIG_FILE)
    fi
    if [ -z "$base_stream" ] || [ "$base_stream" = "0" ]; then
        base_stream=60000
    fi

    # Check if UFW is enabled
    if ! command -v ufw >/dev/null 2>&1; then
        return 0
    fi

    ufw_status=$(sudo ufw status 2>/dev/null | grep -i "Status: active")
    if [ -z "$ufw_status" ]; then
        return 0
    fi

    # Calculate end ports
    local end_p2p=$((base_p2p + worker_count - 1))
    local end_stream=$((base_stream + worker_count - 1))

    echo "Removing firewall rules for worker ports..."
    echo "P2P ports: $base_p2p-$end_p2p"
    echo "Stream ports: $base_stream-$end_stream"

    # Remove range rules for worker ports
    # Get rule numbers for the port ranges and delete them (in reverse order)
    local p2p_rules=$(sudo ufw status numbered 2>/dev/null | grep -E " ${base_p2p}:${end_p2p}/tcp" | awk -F'[][]' '{print $2}')
    if [ -n "$p2p_rules" ]; then
        echo "$p2p_rules" | tac | while read -r rule_num; do
            echo "y" | sudo ufw --force delete "$rule_num" >/dev/null 2>&1
        done
    fi

    local stream_rules=$(sudo ufw status numbered 2>/dev/null | grep -E " ${base_stream}:${end_stream}/tcp" | awk -F'[][]' '{print $2}')
    if [ -n "$stream_rules" ]; then
        echo "$stream_rules" | tac | while read -r rule_num; do
            echo "y" | sudo ufw --force delete "$rule_num" >/dev/null 2>&1
        done
    fi

    echo "Firewall rules removed successfully"
}

# Function to disable manual mode
disable_manual_mode() {
    echo "Disabling manual mode..."

    # Clear worker arrays in quil config
    yq eval -i '.engine.dataWorkerP2PMultiaddrs = []' $QUIL_CONFIG_FILE
    yq eval -i '.engine.dataWorkerStreamMultiaddrs = []' $QUIL_CONFIG_FILE

    # Set qtools config for manual mode
    qtools config set-value manual.enabled "false" --quiet

    echo "Manual mode disabled"
    echo "Note: Firewall rules for worker ports are preserved"
}

# Parse command line arguments
if [ $# -eq 0 ]; then
    echo "Usage: qtools manual-mode --enable [--cores|--workers <count>]"
    echo "       qtools manual-mode --disable"
    exit 1
fi

case "$1" in
    --enable)
        shift
        WORKER_COUNT=""

        # Parse optional --cores or --workers flag
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --cores|--workers)
                    if [ -z "$2" ]; then
                        echo "Error: --cores/--workers requires a value"
                        exit 1
                    fi
                    WORKER_COUNT="$2"
                    shift 2
                    ;;
                *)
                    echo "Unknown option: $1"
                    exit 1
                    ;;
            esac
        done

        enable_manual_mode "$WORKER_COUNT"
        ;;
    --disable)
        disable_manual_mode
        ;;
    *)
        echo "Unknown option: $1"
        echo "Usage: qtools manual-mode --enable [--cores|--workers <count>]"
        echo "       qtools manual-mode --disable"
        exit 1
        ;;
esac

