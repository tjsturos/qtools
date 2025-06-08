#!/bin/bash

# Script to automatically check, download, and execute Quilibrium lunchtime simulator
# based on system architecture and OS

# Ideally this should be run in a tmux session for persistence

# Configuration
CHECK_INTERVAL=300  # 5 minutes in seconds
LOG_FILE="lunchtime-simulator.log"
BINARY_NAME="lunchtime-simulator"

# Function to detect OS and architecture
detect_system() {
    local os=""
    local arch=""

    # Detect OS
    case "$(uname -s)" in
        Linux*)     os="linux";;
        Darwin*)    os="darwin";;
        *)          echo "Unsupported OS: $(uname -s)"
                    exit 1;;
    esac

    # Detect architecture
    case "$(uname -m)" in
        x86_64)     arch="amd64";;
        aarch64|arm64) arch="arm64";;
        *)          echo "Unsupported architecture: $(uname -m)"
                    exit 1;;
    esac

    echo "${os}-${arch}"
}

# Function to log with timestamp (stdout only)
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if URL is active
check_url() {
    local url=$1
    # Use curl with head request to check if URL is accessible
    # -s: silent, -o /dev/null: discard output, -w %{http_code}: write HTTP code
    # -I: HEAD request, -L: follow redirects
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" -I -L "$url" 2>/dev/null)

    if [ "$http_code" = "200" ]; then
        return 0
    else
        return 1
    fi
}

# Function to download and execute binary
download_and_execute() {
    local url=$1

    log "Downloading binary from: $url"

    # Download the binary
    if curl -L -o "$BINARY_NAME" "$url" 2>/dev/null; then
        log "Download successful"

        # Make it executable
        chmod +x "$BINARY_NAME"
        log "Made binary executable"

        # Execute the binary with output to log file only
        log "Starting execution of $BINARY_NAME (output going to $LOG_FILE)"
        ./"$BINARY_NAME" >> "$LOG_FILE" 2>&1 &
        local pid=$!
        log "Started $BINARY_NAME with PID: $pid"

        # Wait for the process to complete
        wait $pid
        local exit_code=$?
        log "Process completed with exit code: $exit_code"

        return 0
    else
        log "ERROR: Failed to download binary"
        return 1
    fi
}

# Main script
main() {
    # Detect system
    local system=$(detect_system)
    local url="https://releases.quilibrium.com/lunchtime-simulator-${system}"

    log "Starting automated testing script"
    log "System detected: $system"
    log "Target URL: $url"
    log "Check interval: $CHECK_INTERVAL seconds"
    log "Application output will be logged to: $LOG_FILE"

    # Main loop
    while true; do
        log "Checking if URL is active..."

        if check_url "$url"; then
            log "URL is active! Proceeding with download and execution"

            if download_and_execute "$url"; then
                log "Successfully completed execution"
                break
            else
                log "Failed to download or execute, will retry in $CHECK_INTERVAL seconds"
            fi
        else
            log "URL not active yet, will check again in $CHECK_INTERVAL seconds"
        fi

        # Wait for the specified interval
        sleep $CHECK_INTERVAL
    done

    log "Script completed"
}

# Run the main function
main

