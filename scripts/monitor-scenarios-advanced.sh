#!/bin/bash

# Advanced monitor for running processes with frame/scenario tracking
# Provides statistics, filtering, and enhanced visualization
# Compatible with macOS default bash (3.2) and Linux bash

PID_TRACKING_FILE="running_processes.json"
SCENARIO_HISTORY_FILE="scenario_history.json"  # Persistence file for scenario history
LOG_POSITION_FILE="log_positions.json"  # Track last processed position in each log file
REFRESH_INTERVAL=10  # seconds between updates
SHOW_LINES=5       # number of recent scenarios to show per instance
LOG_LINES=10000
MAX_HISTORY=20     # maximum number of scenarios to keep in history per instance

# Colors for better visibility
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'
DIM='\033[2m'

# Create temporary directory for storing data
TEMP_DIR="/tmp/qtools_monitor_$$"
mkdir -p "$TEMP_DIR"

# Cleanup temp directory on exit
cleanup_temp() {
    rm -rf "$TEMP_DIR"
}
trap cleanup_temp EXIT

# Helper functions for simulating associative arrays
# Store key-value pairs in temporary files

# Set a value for a given key in a "map"
map_set() {
    local map_name=$1
    local key=$2
    local value=$3
    local file="$TEMP_DIR/${map_name}_$(echo "$key" | sed 's/[^a-zA-Z0-9_-]/_/g')"
    echo "$value" > "$file"
}

# Get a value for a given key from a "map"
map_get() {
    local map_name=$1
    local key=$2
    local default=${3:-}
    local file="$TEMP_DIR/${map_name}_$(echo "$key" | sed 's/[^a-zA-Z0-9_-]/_/g')"
    if [ -f "$file" ]; then
        cat "$file"
    else
        echo "$default"
    fi
}

# Check if a key exists in a "map"
map_exists() {
    local map_name=$1
    local key=$2
    local file="$TEMP_DIR/${map_name}_$(echo "$key" | sed 's/[^a-zA-Z0-9_-]/_/g')"
    [ -f "$file" ]
}

# Get all keys from a "map"
map_keys() {
    local map_name=$1
    for file in "$TEMP_DIR/${map_name}_"*; do
        if [ -f "$file" ]; then
            basename "$file" | sed "s/^${map_name}_//"
        fi
    done 2>/dev/null
}

# Clear a "map"
map_clear() {
    local map_name=$1
    rm -f "$TEMP_DIR/${map_name}_"* 2>/dev/null
}

# Function to save scenario history to file
save_scenario_history() {
    local json_content="{"
    local first=true

    for instance_id in $(map_keys "scenario_history"); do
        if [ "$first" = true ]; then
            first=false
        else
            json_content+=","
        fi

        # Escape the scenario history content for JSON
        local history=$(map_get "scenario_history" "$instance_id")
        local escaped_history=$(echo "$history" | jq -Rs .)
        json_content+="\"$instance_id\":$escaped_history"
    done

    json_content+="}"
    echo "$json_content" > "$SCENARIO_HISTORY_FILE"
}

# Function to load scenario history from file
load_scenario_history() {
    if [ -f "$SCENARIO_HISTORY_FILE" ]; then
        # Read the JSON file and populate the scenario_history map
        while IFS= read -r line; do
            local instance_id=$(echo "$line" | cut -d: -f1 | tr -d '"')
            local history=$(echo "$line" | cut -d: -f2- | jq -r .)
            map_set "scenario_history" "$instance_id" "$history"
        done < <(jq -r 'to_entries | .[] | "\(.key):\(.value)"' "$SCENARIO_HISTORY_FILE" 2>/dev/null)
    fi
}

# Function to save log positions to file
save_log_positions() {
    local json_content="{"
    local first=true

    for log_file in $(map_keys "log_positions"); do
        if [ "$first" = true ]; then
            first=false
        else
            json_content+=","
        fi

        local position=$(map_get "log_positions" "$log_file")
        json_content+="\"$log_file\":${position}"
    done

    json_content+="}"
    echo "$json_content" > "$LOG_POSITION_FILE"
}

# Function to load log positions from file
load_log_positions() {
    if [ -f "$LOG_POSITION_FILE" ]; then
        # Read the JSON file and populate the log_positions map
        while IFS= read -r line; do
            local log_file=$(echo "$line" | cut -d: -f1 | tr -d '"')
            local position=$(echo "$line" | cut -d: -f2)
            map_set "log_positions" "$log_file" "$position"
        done < <(jq -r 'to_entries | .[] | "\(.key):\(.value)"' "$LOG_POSITION_FILE" 2>/dev/null)
    fi
}

# Load history and positions on script start
load_scenario_history
load_log_positions

# Function to extract and analyze log data
analyze_log() {
    local log_file=$1
    local instance_id=$2
    local show_all=${3:-false}

    if [ ! -f "$log_file" ]; then
        echo "ERROR:Log file not found"
        return
    fi

    # Initialize history for this instance if not exists
    if ! map_exists "scenario_history" "$instance_id"; then
        map_set "scenario_history" "$instance_id" ""
    fi

    # Get current file size
    local current_size=$(stat -c%s "$log_file" 2>/dev/null || stat -f%z "$log_file" 2>/dev/null)

    # Get last processed position
    local last_position=$(map_get "log_positions" "$log_file" "0")

    # If file is smaller than last position, it was probably truncated/rotated
    if [ "$current_size" -lt "$last_position" ]; then
        last_position=0
    fi

    # Read only new content from the log file
    local new_content=""
    if [ "$last_position" -eq 0 ]; then
        # First time reading this file, get last LOG_LINES lines
        new_content=$(tail -n "$LOG_LINES" "$log_file" 2>/dev/null)
    else
        # Read from last position to end
        new_content=$(tail -c +$((last_position + 1)) "$log_file" 2>/dev/null)
    fi

    # Update the last processed position
    map_set "log_positions" "$log_file" "$current_size"
    save_log_positions

    # Extract scenario entries from new content
    local entries=$(echo "$new_content" | grep -E "\[Frame [0-9]+\] Running scenario:" 2>/dev/null)

    if [ -z "$entries" ]; then
        # No new data found, return the stored history
        map_get "scenario_history" "$instance_id" | head -n "$SHOW_LINES"
        return
    fi

    # Get latest frame number from all entries (not just new ones)
    local all_entries=$(tail -n "$LOG_LINES" "$log_file" | grep -E "\[Frame [0-9]+\] Running scenario:" 2>/dev/null)
    if [ -n "$all_entries" ]; then
        local latest_frame=$(echo "$all_entries" | tail -1 | grep -oE "Frame [0-9]+" | grep -oE "[0-9]+")
        map_set "frame_progress" "$instance_id" "$latest_frame"
    fi

    # Process only truly new scenarios
    local new_scenarios=""
    local history_updated=false

    while IFS= read -r line; do
        if [[ $line =~ \[Frame[[:space:]]([0-9]+)\][[:space:]]Running[[:space:]]scenario:[[:space:]](.+) ]]; then
            local frame="${BASH_REMATCH[1]}"
            local scenario="${BASH_REMATCH[2]}"

            # Update scenario count
            local current_count=$(map_get "scenario_counts" "$scenario" "0")
            map_set "scenario_counts" "$scenario" "$((current_count + 1))"

            # Add with current timestamp - these are genuinely new entries
            # macOS date doesn't support %N for nanoseconds, so we use a workaround
            local current_timestamp
            if date '+%Y-%m-%d %H:%M:%S.%3N' 2>/dev/null | grep -q '\.[0-9]'; then
                # Linux with nanosecond support
                current_timestamp=$(date '+%Y-%m-%d %H:%M:%S.%3N')
            else
                # macOS or other systems without nanosecond support
                current_timestamp=$(date '+%Y-%m-%d %H:%M:%S')
            fi
            new_scenarios+="[$current_timestamp] [Frame $frame] Running scenario: $scenario\n"
            history_updated=true
        fi
    done <<< "$entries"

    # Update the history for this instance if there are new scenarios
    if [ -n "$new_scenarios" ]; then
        # Combine new scenarios with existing history
        local existing_history=$(map_get "scenario_history" "$instance_id")
        local combined_history="${new_scenarios}${existing_history}"

        # Keep only the most recent MAX_HISTORY scenarios
        local updated_history=$(echo -e "$combined_history" | grep -E "\[[0-9]{4}-[0-9]{2}-[0-9]{2}" | head -n "$MAX_HISTORY")
        map_set "scenario_history" "$instance_id" "$updated_history"

        # Save the updated history to file
        save_scenario_history
    fi

    # Return the most recent SHOW_LINES scenarios from history
    map_get "scenario_history" "$instance_id" | head -n "$SHOW_LINES"
}

# Function to display statistics
display_stats() {
    echo -e "${BOLD}${WHITE}📊 Scenario Statistics:${NC}"

    # Create a temporary file for sorting
    local temp_stats="$TEMP_DIR/stats_temp"
    > "$temp_stats"

    # Collect all scenario counts
    for scenario in $(map_keys "scenario_counts"); do
        local count=$(map_get "scenario_counts" "$scenario")
        echo "$scenario:$count" >> "$temp_stats"
    done

    # Sort and display
    sort -t: -k2 -nr "$temp_stats" | while IFS=: read -r scenario count; do
        printf "  ${CYAN}%-30s${NC} ${YELLOW}%3d${NC} occurrences\n" "$scenario" "$count"
    done

    echo ""
}

# Function to display frame progress
display_progress() {
    echo -e "${BOLD}${WHITE}📈 Frame Progress:${NC}"

    for instance in $(map_keys "frame_progress"); do
        local frame=$(map_get "frame_progress" "$instance")
        printf "  ${BLUE}%-20s${NC} Frame ${GREEN}%3d${NC}\n" "$instance" "$frame"
    done

    echo ""
}

# Function to display the dashboard header
display_header() {
    clear
    echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║          🚀 Quilibrium Test Process Monitor Dashboard 🚀              ║${NC}"
    echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${DIM}Last Updated: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo ""
}

# Function to calculate process runtime
calculate_runtime() {
    local pid=$1

    # Get process start time using ps
    local start_time=$(ps -o lstart= -p "$pid" 2>/dev/null)

    if [ -z "$start_time" ]; then
        echo "N/A"
        return
    fi

    # Convert start time to seconds since epoch
    local start_epoch=$(date -d "$start_time" +%s 2>/dev/null || date -j -f "%a %b %d %T %Y" "$start_time" +%s 2>/dev/null)
    local current_epoch=$(date +%s)

    if [ -z "$start_epoch" ]; then
        echo "N/A"
        return
    fi

    # Calculate runtime in seconds
    local runtime_seconds=$((current_epoch - start_epoch))

    # Format runtime as HH:MM:SS
    local hours=$((runtime_seconds / 3600))
    local minutes=$(((runtime_seconds % 3600) / 60))
    local seconds=$((runtime_seconds % 60))

    printf "%02d:%02d:%02d" $hours $minutes $seconds
}

# Function to display process information
display_process() {
    local process=$1
    local instance_id=$(echo "$process" | jq -r '.instance_id')
    local pid=$(echo "$process" | jq -r '.pid')
    local log_file=$(echo "$process" | jq -r '.log_file')

    echo -e "${BOLD}${BLUE}━━━ Instance: $instance_id ━━━${NC}"
    echo -e "${DIM}PID: $pid | Log: $log_file${NC}"

    # Check if process is still running
    if ps -p "$pid" > /dev/null 2>&1; then
        local runtime=$(calculate_runtime "$pid")
        echo -e "${GREEN}● Status: Running${NC} | ${PURPLE}Runtime: $runtime${NC}"

        # Analyze log
        local log_data=$(analyze_log "$log_file" "$instance_id")

        if [[ $log_data == "ERROR:"* ]]; then
            echo -e "  ${RED}${log_data#ERROR:}${NC}"
        elif [ -z "$log_data" ]; then
            echo -e "  ${YELLOW}No scenarios recorded recently${NC}"
        else
            echo -e "${YELLOW}📋 Recent Scenarios:${NC}"
            echo "$log_data" | while IFS= read -r line; do
                if [ -n "$line" ] && [ "$line" != "n" ]; then
                    if [[ $line =~ \[([0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{3})?)\][[:space:]]\[Frame[[:space:]]([0-9]+)\][[:space:]]Running[[:space:]]scenario:[[:space:]](.+) ]]; then
                        local timestamp="${BASH_REMATCH[1]}"
                        local frame="${BASH_REMATCH[3]}"
                        local scenario="${BASH_REMATCH[4]}"
                        printf "  ${DIM}%s${NC} ${CYAN}[Frame %3s]${NC} %s\n" "$timestamp" "$frame" "$scenario"
                    fi
                fi
            done
        fi
    else
        echo -e "${RED}● Status: Not Running${NC}"
        echo -e "  ${DIM}Process may have completed or crashed${NC}"

        # Show last known scenarios from history if available
        local last_known_history=$(map_get "scenario_history" "$instance_id")
        if [ -n "$last_known_history" ]; then
            echo -e "${YELLOW}📋 Last Known Scenarios:${NC}"
            echo "$last_known_history" | head -n "$SHOW_LINES" | while IFS= read -r line; do
                if [ -n "$line" ]; then
                    if [[ $line =~ \[([0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{3})?)\][[:space:]]\[Frame[[:space:]]([0-9]+)\][[:space:]]Running[[:space:]]scenario:[[:space:]](.+) ]]; then
                        local timestamp="${BASH_REMATCH[1]}"
                        local frame="${BASH_REMATCH[3]}"
                        local scenario="${BASH_REMATCH[4]}"
                        printf "  ${DIM}%s ${CYAN}[Frame %3s]${NC} %s${NC}\n" "$timestamp" "$frame" "$scenario"
                    fi
                fi
            done
        fi
    fi

    echo ""
}

# Function to display the full dashboard
display_dashboard() {
    # Clear statistics for fresh count (but preserve scenario history)
    map_clear "scenario_counts"
    map_clear "frame_progress"
    # Note: scenario_history is NOT cleared to maintain persistence

    display_header

    # Check if tracking file exists
    if [ ! -f "$PID_TRACKING_FILE" ]; then
        echo -e "${RED}❌ No running processes tracking file found${NC}"
        echo -e "${YELLOW}💡 Start test instances using: ./scripts/automate-testing.sh${NC}"
        return
    fi

    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}❌ jq is not installed${NC}"
        echo -e "${YELLOW}💡 Install with: sudo apt-get install jq${NC}"
        return
    fi

    # Get process count
    local process_count=$(jq '.processes | length' "$PID_TRACKING_FILE" 2>/dev/null || echo "0")

    if [ "$process_count" -eq "0" ]; then
        echo -e "${YELLOW}⚠️  No processes are currently running${NC}"
        return
    fi

    echo -e "${GREEN}✅ Active Processes: $process_count${NC}"
    echo ""

    # Process each instance
    jq -c '.processes[]' "$PID_TRACKING_FILE" | while read -r process; do
        display_process "$process"
    done

    # Display statistics
    if [ -n "$(map_keys "scenario_counts")" ]; then
        display_stats
    fi

    if [ -n "$(map_keys "frame_progress")" ]; then
        display_progress
    fi
}

# Function to run in monitoring mode
monitor_mode() {
    echo -e "${CYAN}🔄 Starting continuous monitoring...${NC}"
    echo -e "${YELLOW}Press Ctrl+C to exit${NC}"
    sleep 2

    # Cleanup function to save history on exit
    cleanup_monitor() {
        echo -e "\n${YELLOW}Saving scenario history and log positions...${NC}"
        save_scenario_history
        save_log_positions
        echo -e "${GREEN}Monitor stopped.${NC}"
        cleanup_temp  # Also clean up temp directory
        exit 0
    }

    trap cleanup_monitor INT

    while true; do
        display_dashboard
        sleep "$REFRESH_INTERVAL"
    done
}

# Function to export data
export_data() {
    local output_file="${1:-process_monitor_export_$(date +%Y%m%d_%H%M%S).txt}"

    {
        echo "Quilibrium Process Monitor Export"
        echo "Generated: $(date)"
        echo "================================"
        echo ""

        if [ -f "$PID_TRACKING_FILE" ]; then
            jq -c '.processes[]' "$PID_TRACKING_FILE" | while read -r process; do
                local instance_id=$(echo "$process" | jq -r '.instance_id')
                local log_file=$(echo "$process" | jq -r '.log_file')

                echo "Instance: $instance_id"
                echo "Log file: $log_file"
                echo "Scenarios:"

                if [ -f "$log_file" ]; then
                    grep -E "\[Frame [0-9]+\] Running scenario:" "$log_file" || echo "  No scenarios found"
                else
                    echo "  Log file not found"
                fi

                echo ""
                echo "---"
                echo ""
            done
        else
            echo "No tracking file found"
        fi
    } > "$output_file"

    echo -e "${GREEN}✅ Data exported to: $output_file${NC}"
}

# Main script with command line options
case "${1:-monitor}" in
    "once")
        display_dashboard
        ;;
    "export")
        export_data "$2"
        ;;
    "clear-history")
        echo -e "${YELLOW}Clearing scenario history and log positions...${NC}"
        rm -f "$SCENARIO_HISTORY_FILE" "$LOG_POSITION_FILE"
        echo -e "${GREEN}✅ Scenario history and log positions cleared${NC}"
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [command] [options]"
        echo ""
        echo "Commands:"
        echo "  monitor       - Run in continuous monitoring mode (default)"
        echo "  once          - Display dashboard once and exit"
        echo "  export        - Export all scenario data to a file"
        echo "  clear-history - Clear the persisted scenario history and log positions"
        echo "  help          - Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0                    # Start monitoring"
        echo "  $0 once               # Show dashboard once"
        echo "  $0 export output.txt  # Export to specific file"
        echo "  $0 clear-history      # Clear scenario history"
        ;;
    "monitor"|*)
        monitor_mode
        ;;
esac