#!/bin/bash

# Script to automatically check, download, and execute Quilibrium lunchtime simulator
# based on system architecture and OS

# Ideally this should be run in a tmux session for persistence

# Configuration
CHECK_INTERVAL=300  # 5 minutes in seconds
LOG_DIR="logs"
BINARY_NAME="lunchtime-simulator"

# Global array to track PIDs of running applications
declare -A APP_PIDS=()  # Associative array: PID -> instance_id

# Function to log_to_user with timestamp (stdout only)
log_to_user() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to calculate number of parallel instances
calculate_parallel_instances() {
    local cores=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "8")
    local instances=$((cores / 8))

    # Ensure at least 1 instance
    if [ $instances -lt 1 ]; then
        instances=1
    fi

    echo $instances
}

# Function to handle cleanup on exit
cleanup() {
    log_to_user "Caught interrupt signal, cleaning up..."

    # Kill all running application instances
    for pid in "${!APP_PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            log_to_user "Terminating $BINARY_NAME (PID: $pid, Instance: ${APP_PIDS[$pid]})..."
            kill -TERM "$pid"
        fi
    done

    # Wait a bit for graceful shutdown
    sleep 2

    # Force kill any remaining processes
    for pid in "${!APP_PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            log_to_user "Force killing $BINARY_NAME (PID: $pid)..."
            kill -KILL "$pid"
        fi
    done

    log_to_user "Cleanup complete, exiting."
    exit 0
}

# Set up trap for SIGINT (Ctrl+C) and SIGTERM
trap cleanup SIGINT SIGTERM

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

LOG_FILE="lunchtime-simulator.log"
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

    log_to_user "Downloading binary from: $url"

    # Download the binary
    if curl -L -o "$BINARY_NAME" "$url" 2>/dev/null; then
        log_to_user "Download successful"

        # Make it executable
        chmod +x "$BINARY_NAME"
        log_to_user "Made binary executable"

        return 0
    else
        log_to_user "ERROR: Failed to download binary"
        return 1
    fi
}

# Function to run a single instance of the binary
run_binary_instance() {
    local instance_id=$1
    local run_number=$2
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local log_file="${LOG_DIR}/lunchtime-simulator-instance${instance_id}-run${run_number}-${timestamp}.log"

    log_to_user "[Instance $instance_id] Starting execution run #$run_number (output going to $log_file)"
    ./"$BINARY_NAME" >> "$log_file" 2>&1 &
    local pid=$!
    log_to_user "[Instance $instance_id] Started run #$run_number with PID: $pid"

    echo $pid
}

# Function to maintain parallel instances
maintain_parallel_instances() {
    local target_instances=$1
    local -A instance_run_count  # Track run count per instance
    local total_runs=0

    # Initialize instance run counts
    for ((i=1; i<=target_instances; i++)); do
        instance_run_count[$i]=0
    done

    # Start initial instances
    log_to_user "Starting initial $target_instances instances..."
    for ((i=1; i<=target_instances; i++)); do
        instance_run_count[$i]=$((instance_run_count[$i] + 1))
        total_runs=$((total_runs + 1))
        local pid=$(run_binary_instance $i ${instance_run_count[$i]})
        APP_PIDS[$pid]=$i
    done

    # Continuously maintain the target number of instances
    while true; do
        # Check for completed processes and restart them
        for pid in "${!APP_PIDS[@]}"; do
            if ! kill -0 "$pid" 2>/dev/null; then
                # Process has finished
                wait "$pid" 2>/dev/null
                local exit_code=$?
                local instance_id=${APP_PIDS[$pid]}
                log_to_user "[Instance $instance_id] Process (PID: $pid) completed with exit code: $exit_code"

                # Remove from tracking
                unset APP_PIDS[$pid]

                # Start a new instance immediately
                instance_run_count[$instance_id]=$((instance_run_count[$instance_id] + 1))
                total_runs=$((total_runs + 1))
                log_to_user "[Instance $instance_id] Total runs across all instances: $total_runs"

                local new_pid=$(run_binary_instance $instance_id ${instance_run_count[$instance_id]})
                APP_PIDS[$new_pid]=$instance_id

                # Small delay to prevent tight loop
                sleep 0.1
            fi
        done

        # Small sleep to prevent CPU spinning
        sleep 1
    done
}

# Main script
main() {
    # Create logs directory if it doesn't exist
    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR"
        log_to_user "Created logs directory: $LOG_DIR"
    fi

    # Detect system
    local system=$(detect_system)
    local url="https://releases.quilibrium.com/lunchtime-simulator-${system}"

    # Calculate parallel instances
    local cores=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "8")
    local parallel_instances=$(calculate_parallel_instances)

    log_to_user "Starting automated testing script"
    log_to_user "System detected: $system"
    log_to_user "CPU cores detected: $cores"
    log_to_user "Parallel instances to run: $parallel_instances (cores/8)"
    log_to_user "Target URL: $url"
    log_to_user "Check interval: $CHECK_INTERVAL seconds"
    log_to_user "Log files will be stored in: $LOG_DIR"

    local binary_downloaded=false

    # Main loop - first wait for binary to be available and download it
    while [ "$binary_downloaded" = false ]; do
        log_to_user "Checking if URL is active..."

        if check_url "$url"; then
            log_to_user "URL is active! Proceeding with download"

            if download_and_execute "$url"; then
                log_to_user "Successfully downloaded binary"
                binary_downloaded=true
            else
                log_to_user "Failed to download, will retry in $CHECK_INTERVAL seconds"
                sleep $CHECK_INTERVAL
            fi
        else
            log_to_user "URL not active yet, will check again in $CHECK_INTERVAL seconds"
            sleep $CHECK_INTERVAL
        fi
    done

    # Now continuously maintain the target number of parallel instances
    log_to_user "Starting continuous execution with $parallel_instances parallel instances (press Ctrl+C to stop)"
    log_to_user "Each instance will restart immediately upon completion"

    maintain_parallel_instances $parallel_instances
}

# Run the main function
main

