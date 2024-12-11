#!/bin/bash

# Get list of active dataworker services
active_workers=$(systemctl list-units --type=service --state=active | grep "dataworker@" | awk '{print $1}')

# Memory threshold in KB (200MB = 204800KB)
MEM_THRESHOLD=204800

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --threshold)
            if [[ $2 =~ ^[0-9]+$ ]]; then
                MEM_THRESHOLD=$2
                shift 2
            else
                echo "Error: Threshold must be a number in KB"
                exit 1
            fi
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--threshold <memory_in_kb>]"
            exit 1
            ;;
    esac
done


for worker in $active_workers; do
    # Get memory usage in KB for the service
    mem_usage=$(ps -o rss= -p $(systemctl show -p MainPID --value "$worker") | tr -d ' ')
    
    if [ -n "$mem_usage" ] && [ "$mem_usage" -gt "$MEM_THRESHOLD" ]; then
        echo -e "${BLUE}${INFO_ICON} Restarting $worker due to high memory usage (${mem_usage}KB)${RESET}"
        sudo systemctl restart "$worker"
    fi
done
