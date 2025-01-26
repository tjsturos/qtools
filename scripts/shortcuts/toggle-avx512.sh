#!/bin/bash

CONFIG_FILE="$HOME/ceremonyclient/config.yml"
MANUAL_STATE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --on)
            MANUAL_STATE="true"
            shift
            ;;
        --off)
            MANUAL_STATE="false" 
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Function to get current AVX-512 state from config
get_current_state() {
    local current_state=$(yq e '.settings.use_avx512' "$CONFIG_FILE")
    echo "$current_state"
}

# Function to set AVX-512 state
set_avx512_state() {
    local state=$1
    yq e ".settings.use_avx512 = $state" -i "$CONFIG_FILE"
    echo "AVX-512 has been set to: $state"
}

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file not found at $CONFIG_FILE"
    exit 1
fi

CURRENT_STATE=$(get_current_state)

if [ "$MANUAL_STATE" == "true" ]; then
    set_avx512_state true
elif [ "$MANUAL_STATE" == "off" ]; then
    set_avx512_state false
elif [ "$CURRENT_STATE" == "false" ]; then
    set_avx512_state true
else
    set_avx512_state false
fi 