#!/bin/bash

# Get list of active dataworker services
active_workers=$(systemctl list-units --type=service --state=active | grep "dataworker@" | awk '{print $1}')

# Memory threshold in MB (default 200MB)
MEM_THRESHOLD=200

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --threshold|-t)
            if [[ $2 =~ ^[0-9]+$ ]]; then
                MEM_THRESHOLD=$2
                shift 2
            else
                echo "Error: Threshold must be a number in MB"
                exit 1
            fi
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--threshold <memory_in_mb>]"
            exit 1
            ;;
    esac
done


# Initialize counter for workers above threshold
workers_to_restart=()
count=0

for worker in $active_workers; do
    # Get memory usage in KB for the service
    mem_usage=$(ps -o rss= -p $(systemctl show -p MainPID --value "$worker") | tr -d ' ')
    
    if [ -n "$mem_usage" ] && [ "$mem_usage" -gt "$((MEM_THRESHOLD * 1024))" ]; then
        workers_to_restart+=("$worker")
        
        # Once we hit 10 workers, restart them and clear the array
        if [ ${#workers_to_restart[@]} -eq 10 ]; then
            echo -e "${BLUE}${INFO_ICON} Restarting ${#workers_to_restart[@]} workers due to high memory usage${RESET}"
            count=$((count + ${#workers_to_restart[@]}))
            sudo systemctl restart "${workers_to_restart[@]}"
            workers_to_restart=()
        fi
    fi
done



echo -e "${BLUE}${INFO_ICON} Total workers restarted due to high memory usage: ${#workers_to_restart}${RESET}"

unset workers_to_restart
