#!/usr/bin/env bash

set -euo pipefail

# Standalone script: iterate config dirs/files, run node --node-info --config <cfg>,
# extract Peer ID and Seniority, sort by seniority desc, print "$PEER_ID: $SENIORITY"

usage() {
    echo "Usage: $(basename "$0") <configs_parent_dir> [--node-binary /path/to/node]" >&2
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
    usage
    exit 0
fi

if [[ $# -lt 1 ]]; then
    usage
    exit 1
fi

CONFIGS_PARENT_DIR="$1"; shift || true
NODE_BINARY_OVERRIDE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --node-binary)
            NODE_BINARY_OVERRIDE="${2:-}"
            shift 2 || true
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage
            exit 1
            ;;
    esac
done

find_node_binary() {
    # If user provided an override, use it if executable
    if [[ -n "$NODE_BINARY_OVERRIDE" ]]; then
        if [[ -x "$NODE_BINARY_OVERRIDE" ]]; then
            echo "$NODE_BINARY_OVERRIDE"
            return 0
        else
            echo "Provided --node-binary is not executable: $NODE_BINARY_OVERRIDE" >&2
            return 1
        fi
    fi

    # Prefer ./node if present and executable
    if [[ -x "./node" ]]; then
        echo "./node"
        return 0
    fi

    # Fall back to most recently modified matching ./node-*
    local latest
    latest="$(ls -1t ./node-* 2>/dev/null | head -n 1 || true)"
    if [[ -n "$latest" && -x "$latest" ]]; then
        echo "$latest"
        return 0
    fi

    echo "Unable to locate an executable node binary in current directory (looked for ./node and ./node-*)" >&2
    return 1
}

NODE_BIN="$(find_node_binary)" || exit 1

if [[ ! -d "$CONFIGS_PARENT_DIR" ]]; then
    echo "Configs parent directory not found: $CONFIGS_PARENT_DIR" >&2
    exit 1
fi

# Collect results as "peer|seniority"
RESULTS_TMP="$(mktemp)"
trap 'rm -f "$RESULTS_TMP"' EXIT

shopt -s nullglob

for CFG in "$CONFIGS_PARENT_DIR"/*; do
    # Accept both directories and files as configs
    if [[ -d "$CFG" || -f "$CFG" ]]; then
        # Run node-info for this config
        OUTPUT="$($NODE_BIN --node-info --config "$CFG" 2>/dev/null || true)"

        # Parse Peer ID and Seniority
        PEER_ID="$(echo "$OUTPUT" | awk -F'Peer ID: ' '/Peer ID:/ {print $2; exit}' | tr -d '\r' | xargs || true)"
        SENIORITY_RAW="$(echo "$OUTPUT" | awk -F'Seniority: ' '/Seniority:/ {print $2; exit}' | tr -d '\r' | xargs || true)"
        SENIORITY="$(echo "$SENIORITY_RAW" | grep -oE '[0-9]+' | head -n 1 || true)"

        if [[ -n "$PEER_ID" && -n "$SENIORITY" ]]; then
            echo "$PEER_ID|$SENIORITY" >> "$RESULTS_TMP"
        fi
    fi
done

if [[ ! -s "$RESULTS_TMP" ]]; then
    echo "No results found. Ensure configs exist and node --node-info works locally." >&2
    exit 2
fi

# Sort by seniority (numeric, desc) and print "$PEER_ID: $SENIORITY"
sort -t '|' -k2,2nr "$RESULTS_TMP" | awk -F'|' '{print $1": "$2}'


