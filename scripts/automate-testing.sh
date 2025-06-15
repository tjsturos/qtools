#!/bin/bash

# Script to automatically check, download, and execute Quilibrium lunchtime simulator
# based on system architecture and OS

# Ideally this should be run in a tmux session for persistence

# Configuration
CHECK_INTERVAL=300  # 5 minutes in seconds
LOG_DIR="logs"
BINARY_NAME="lunchtime-simulator"
PID_TRACKING_FILE="running_processes.json"
MONITOR_SCRIPT="monitor-scenarios-advanced.sh"
MONITOR_SCRIPT_URL="https://raw.githubusercontent.com/tjsturos/qtools/refs/heads/main/scripts/monitor-scenarios-advanced.sh"

# Global array to track PIDs of running applications
APP_PIDS=()  # Associative array: PID -> instance_id
APP_LOGS=()  # Associative array: PID -> log_file

# Color codes for alternating instance colors
# Check if terminal supports colors (check stderr since we output colors there)
if [ -t 2 ] && [ -n "${TERM}" ] && [ "${TERM}" != "dumb" ]; then
    COLOR_ODD="\033[1;36m"   # Bright cyan for odd instances
    COLOR_EVEN="\033[1;35m"  # Bright magenta for even instances
    COLOR_ERROR="\033[1;31m"  # Bright red for errors
    COLOR_CLEANUP="\033[1;33m" # Bright yellow for cleanup messages
    COLOR_INFO="\033[1;32m"  # Bright green for important startup info
    COLOR_RESET="\033[0m"    # Reset color
else
    # No color support
    COLOR_ODD=""
    COLOR_EVEN=""
    COLOR_ERROR=""
    COLOR_CLEANUP=""
    COLOR_INFO=""
    COLOR_RESET=""
fi

# Function to get color based on instance ID
get_instance_color() {
    local instance_id=$1
    if [ $((instance_id % 2)) -eq 1 ]; then
        echo "$COLOR_ODD"
    else
        echo "$COLOR_EVEN"
    fi
}

# Function to log_to_user with timestamp (stdout only)
log_to_user() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to calculate number of parallel instances
calculate_parallel_instances() {
    local cores=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "8")
    local instances=$((cores / 8))

    # Ensure at least 1 instance
    if [ $instances -lt 1 ] || [ $cores -eq 8 ]; then
        instances=1
    fi

    echo $instances
}

# Function to update PID tracking file
update_pid_tracking_file() {
    local temp_file="${PID_TRACKING_FILE}.tmp"

    # Start JSON array
    echo "{" > "$temp_file"
    echo "  \"last_updated\": \"$(date -u '+%Y-%m-%dT%H:%M:%SZ')\"," >> "$temp_file"
    echo "  \"processes\": [" >> "$temp_file"

    local first=true
    for pid in "${!APP_PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            if [ "$first" = false ]; then
                echo "," >> "$temp_file"
            fi
            echo -n "    {" >> "$temp_file"
            echo -n "\"pid\": $pid, " >> "$temp_file"
            echo -n "\"instance_id\": ${APP_PIDS[$pid]}, " >> "$temp_file"
            echo -n "\"log_file\": \"${APP_LOGS[$pid]}\"" >> "$temp_file"
            echo -n "}" >> "$temp_file"
            first=false
        fi
    done

    echo "" >> "$temp_file"
    echo "  ]" >> "$temp_file"
    echo "}" >> "$temp_file"

    # Atomically replace the file
    mv "$temp_file" "$PID_TRACKING_FILE"
}

# Function to handle cleanup on exit
cleanup() {
    log_to_user "${COLOR_CLEANUP}Caught interrupt signal, cleaning up...${COLOR_RESET}"

    # Kill all running application instances
    for pid in "${!APP_PIDS[@]}"; do
        if pgrep -f "$BINARY_NAME" > /dev/null; then
            log_to_user "${COLOR_CLEANUP}Terminating all instances of $BINARY_NAME...${COLOR_RESET}"
            stop_all_processes
        fi
    done

    # Wait a bit for graceful shutdown
    sleep 2

    # Force kill any remaining processes
    for pid in "${!APP_PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            log_to_user "${COLOR_CLEANUP}Force killing $BINARY_NAME (PID: $pid)...${COLOR_RESET}"
            kill -KILL "$pid"
        fi
    done

    # Remove PID tracking file
    if [ -f "$PID_TRACKING_FILE" ]; then
        log_to_user "${COLOR_CLEANUP}Removing PID tracking file...${COLOR_RESET}"
        rm -f "$PID_TRACKING_FILE"
    fi

    log_to_user "${COLOR_CLEANUP}Cleanup complete, exiting.${COLOR_RESET}"
    exit 0
}

# Set up trap for SIGINT (Ctrl+C) and SIGTERM
trap cleanup SIGINT SIGTERM

# Function to check and download monitor script
check_and_download_monitor_script() {
    if [ ! -f "$MONITOR_SCRIPT" ]; then
        log_to_user "${COLOR_INFO}Monitor script not found. Downloading from GitHub...${COLOR_RESET}"

        if curl -L -o "$MONITOR_SCRIPT" "$MONITOR_SCRIPT_URL" 2>/dev/null; then
            chmod +x "$MONITOR_SCRIPT"
            log_to_user "${COLOR_INFO}Monitor script downloaded successfully: $MONITOR_SCRIPT${COLOR_RESET}"
            return 0
        else
            log_to_user "${COLOR_ERROR}Failed to download monitor script from: $MONITOR_SCRIPT_URL${COLOR_RESET}"
            log_to_user "${COLOR_CLEANUP}You can manually download it or the script will continue without it${COLOR_RESET}"
            return 1
        fi
    else
        log_to_user "${COLOR_INFO}Monitor script already exists: $MONITOR_SCRIPT${COLOR_RESET}"
        return 0
    fi
}

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

# Function to get remote binary content-length
get_remote_binary_size() {
    local url=$1
    # Use curl to get headers and extract content-length
    local content_length=$(curl -sI "$url" 2>/dev/null | grep -i "content-length:" | awk '{print $2}' | tr -d '\r')

    if [ -n "$content_length" ]; then
        echo "$content_length"
        return 0
    else
        echo "0"
        return 1
    fi
}

# Function to get local binary size
get_local_binary_size() {
    if [ -f "$BINARY_NAME" ]; then
        stat -c%s "$BINARY_NAME" 2>/dev/null || stat -f%z "$BINARY_NAME" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Function to stop all running processes
stop_all_processes() {
    log_to_user "${COLOR_CLEANUP}Stopping all running processes for update...${COLOR_RESET}"

    # Kill all running application instances
    pkill -f "$BINARY_NAME" > /dev/null 2>&1

    # Wait a bit for graceful shutdown
    sleep 2

    # Clear the tracking arrays
    APP_PIDS=()
    APP_LOGS=()

    # Update PID tracking file to show no processes running
    update_pid_tracking_file

    log_to_user "${COLOR_CLEANUP}All processes stopped${COLOR_RESET}"
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

    # Start with a temporary log file name
    local temp_log_file="${LOG_DIR}/lunchtime-simulator-instance${instance_id}-run${run_number}-${timestamp}-temp.log"

    # Start the process
    ./"$BINARY_NAME" >> "$temp_log_file" 2>&1 &
    local pid=$!

    # Now rename the log file to include the PID
    local log_file="${LOG_DIR}/lunchtime-simulator-instance${instance_id}-run${run_number}-pid${pid}-${timestamp}.log"
    mv "$temp_log_file" "$log_file"

    # Return both PID and log file path
    echo "$pid|$log_file"
}

# Function to check and perform binary update if needed
check_and_update_binary() {
    local url=$1
    local force_update=${2:-false}

    # Get remote and local sizes
    local remote_size=$(get_remote_binary_size "$url")
    local local_size=$(get_local_binary_size)

    # Check if update is needed
    if [ "$remote_size" = "0" ]; then
        # Silently skip if we can't get remote size
        return 1
    fi

    if [ "$local_size" = "0" ] || [ "$remote_size" != "$local_size" ] || [ "$force_update" = true ]; then
        if [ "$local_size" = "0" ]; then
            log_to_user "Local binary not found, downloading..."
        elif [ "$force_update" = true ]; then
            log_to_user "Force update requested, downloading..."
        else
            log_to_user "Binary size mismatch detected, update required!"
            log_to_user "Remote binary size: $remote_size bytes"
            log_to_user "Local binary size: $local_size bytes"
        fi

        # Stop all running processes
        stop_all_processes

        # Remove old binary if it exists
        if [ -f "$BINARY_NAME" ]; then
            log_to_user "Removing old binary"
            rm -f "$BINARY_NAME"
        fi

        # Download new binary
        if download_and_execute "$url"; then
            log_to_user "Binary updated successfully"

            # Verify the downloaded size matches expected
            local new_local_size=$(get_local_binary_size)
            if [ "$new_local_size" = "$remote_size" ]; then
                log_to_user "Downloaded binary size verified: $new_local_size bytes"
                return 0
            else
                log_to_user "WARNING: Downloaded binary size ($new_local_size) doesn't match expected size ($remote_size)"
                return 1
            fi
        else
            log_to_user "Failed to download update"
            return 1
        fi
    else
        # Binary is up to date - no message needed
        return 0
    fi
}

# Function to maintain parallel instances
maintain_parallel_instances() {
    local target_instances=$1
    local url=$2
    local instance_run_count=()  # Track run count per instance
    local total_runs=0
    local last_update_check=$(date +%s)
    local update_check_interval=$CHECK_INTERVAL  # Use same interval as main check

    # Initialize instance run counts
    for ((i=1; i<=target_instances; i++)); do
        instance_run_count[$i]=0
    done

    # Start initial instances
    log_to_user "${COLOR_INFO}Starting initial $target_instances instances...${COLOR_RESET}"
    for ((i=1; i<=target_instances; i++)); do
        instance_run_count[$i]=$((instance_run_count[$i] + 1))
        total_runs=$((total_runs + 1))
        local result=$(run_binary_instance $i ${instance_run_count[$i]})
        local pid=$(echo "$result" | cut -d'|' -f1)
        local log_file=$(echo "$result" | cut -d'|' -f2)
        APP_PIDS[$pid]=$i
        APP_LOGS[$pid]=$log_file

        # Log the instance start
        local instance_color=$(get_instance_color $i)
        log_to_user "${instance_color}[Instance $i] Started run #${instance_run_count[$i]} with PID: $pid ($log_file)${COLOR_RESET}"
    done

    # Update PID tracking file after starting all initial instances
    update_pid_tracking_file

    # Continuously maintain the target number of instances
    while true; do
        # Check if it's time to check for updates
        local current_time=$(date +%s)
        local time_since_last_check=$((current_time - last_update_check))

        if [ $time_since_last_check -ge $update_check_interval ]; then
            # Check for updates silently
            if check_and_update_binary "$url"; then
                # If binary was updated, restart all instances
                if [ ${#APP_PIDS[@]} -eq 0 ]; then
                    log_to_user "Binary was updated, restarting all instances..."

                    # Reset instance run counts
                    for ((i=1; i<=target_instances; i++)); do
                        instance_run_count[$i]=0
                    done

                    # Start all instances fresh
                    for ((i=1; i<=target_instances; i++)); do
                        instance_run_count[$i]=$((instance_run_count[$i] + 1))
                        total_runs=$((total_runs + 1))
                        local result=$(run_binary_instance $i ${instance_run_count[$i]})
                        local pid=$(echo "$result" | cut -d'|' -f1)
                        local log_file=$(echo "$result" | cut -d'|' -f2)
                        APP_PIDS[$pid]=$i
                        APP_LOGS[$pid]=$log_file

                        # Log the instance start
                        local instance_color=$(get_instance_color $i)
                        log_to_user "${instance_color}[Instance $i] Started run #${instance_run_count[$i]} with PID: $pid ($log_file)${COLOR_RESET}"
                    done

                    # Update PID tracking file after restarting all instances
                    update_pid_tracking_file
                fi
            fi

            last_update_check=$current_time
        fi

        # Check for completed processes and restart them
        for pid in "${!APP_PIDS[@]}"; do
            if ! kill -0 "$pid" 2>/dev/null; then
                # Process has finished
                wait "$pid" 2>/dev/null
                local exit_code=$?
                local instance_id=${APP_PIDS[$pid]}
                local log_file=${APP_LOGS[$pid]}
                local instance_color=$(get_instance_color $instance_id)

                if [ $exit_code -eq 0 ]; then
                    log_to_user "${instance_color}[Instance $instance_id] ✓ Process (PID: $pid) completed successfully${COLOR_RESET}"
                else
                    log_to_user "${COLOR_ERROR}[Instance $instance_id] ✗ Process (PID: $pid) failed with exit code: $exit_code${COLOR_RESET}"
                    log_to_user "${COLOR_ERROR}[Instance $instance_id] ⚠️  ERROR LOG FILE: $log_file${COLOR_RESET}"

                    # Log error to winners.log
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR - Instance: $instance_id, PID: $pid, Exit Code: $exit_code, Log File: $log_file" >> "${LOG_DIR}/winners.log"
                fi

                # Remove from tracking
                unset APP_PIDS[$pid]
                unset APP_LOGS[$pid]

                # Start a new instance immediately
                instance_run_count[$instance_id]=$((instance_run_count[$instance_id] + 1))
                total_runs=$((total_runs + 1))
                log_to_user "${instance_color}[Instance $instance_id] Total runs across all instances: $total_runs${COLOR_RESET}"

                local result=$(run_binary_instance $instance_id ${instance_run_count[$instance_id]})
                local new_pid=$(echo "$result" | cut -d'|' -f1)
                local new_log_file=$(echo "$result" | cut -d'|' -f2)
                APP_PIDS[$new_pid]=$instance_id
                APP_LOGS[$new_pid]=$new_log_file

                # Log the instance restart
                log_to_user "${instance_color}[Instance $instance_id] Started run #${instance_run_count[$instance_id]} with PID: $new_pid ($new_log_file)${COLOR_RESET}"

                # Update PID tracking file
                update_pid_tracking_file

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
        log_to_user "${COLOR_INFO}Created logs directory: $LOG_DIR${COLOR_RESET}"
    fi

    # Check and download monitor script if needed
    check_and_download_monitor_script

    # Detect system
    local system=$(detect_system)
    local url="https://releases.quilibrium.com/lunchtime-simulator-${system}"

    # Calculate parallel instances
    local cores=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "8")
    local parallel_instances=$(calculate_parallel_instances)

    log_to_user "${COLOR_INFO}Starting automated testing script with auto-update${COLOR_RESET}"
    log_to_user "${COLOR_INFO}System detected: $system${COLOR_RESET}"
    log_to_user "${COLOR_INFO}CPU cores detected: $cores${COLOR_RESET}"
    log_to_user "${COLOR_INFO}Parallel instances to run: $parallel_instances (cores/8)${COLOR_RESET}"
    log_to_user "${COLOR_INFO}Target URL: $url${COLOR_RESET}"
    log_to_user "${COLOR_INFO}Update check interval: $CHECK_INTERVAL seconds${COLOR_RESET}"
    log_to_user "${COLOR_INFO}Log files will be stored in: $LOG_DIR${COLOR_RESET}"
    log_to_user "${COLOR_INFO}Errors will be logged to: $LOG_DIR/winners.log${COLOR_RESET}"
    log_to_user "${COLOR_INFO}Process tracking file: $PID_TRACKING_FILE${COLOR_RESET}"
    log_to_user "${COLOR_INFO}Monitor script: ./$MONITOR_SCRIPT (run in another terminal to monitor progress)${COLOR_RESET}"

    # Main loop - first wait for binary to be available and download it
    while true; do
        log_to_user "Checking if URL is active..."

        if check_url "$url"; then
            log_to_user "URL is active! Checking for binary..."

            # Use the update function to download initial binary (no force update)
            if check_and_update_binary "$url"; then
                log_to_user "Binary ready, starting execution"
                break
            else
                log_to_user "Failed to download binary, will retry in $CHECK_INTERVAL seconds"
                sleep $CHECK_INTERVAL
            fi
        else
            log_to_user "URL not active yet, will check again in $CHECK_INTERVAL seconds"
            sleep $CHECK_INTERVAL
        fi
    done

    # Now continuously maintain the target number of parallel instances with auto-update
    log_to_user "${COLOR_INFO}Starting continuous execution with $parallel_instances parallel instances (press Ctrl+C to stop)${COLOR_RESET}"
    log_to_user "${COLOR_INFO}Each instance will restart immediately upon completion${COLOR_RESET}"
    log_to_user "${COLOR_INFO}Binary will be automatically updated every $CHECK_INTERVAL seconds if a new version is available${COLOR_RESET}"

    maintain_parallel_instances $parallel_instances "$url"
}

# Run the main function
main