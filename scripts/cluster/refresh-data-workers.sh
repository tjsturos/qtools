#!/bin/bash
# HELP: Will restart all data worker services on the current node.
#
# USAGE: qtools refresh-data-workers # Will restart all data worker services on the current node
# USAGE: qtools refresh-data-workers -m -t 80 # Check memory usage and restart data workers if memory usage is greater than the threshold 80\%
#
# OPTIONS:
# PARAM: -m, --memory    Check memory usage and restart data workers if memory usage is greater than the threshold
# PARAM: -t, --threshold Check memory usage and restart data workers if memory usage is greater than the threshold

source $QTOOLS_PATH/scripts/cluster/utils.sh

MEMORY_CHECK=false
THRESHOLD=80
# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--threshold)
            if ! [[ "$2" =~ ^[0-9]+$ ]] || [ "$2" -lt 1 ] || [ "$2" -gt 100 ]; then
                echo "Error: Threshold must be a number between 1 and 100"
                exit 1
            fi
            THRESHOLD=$2
            shift
            shift
            ;;
        -m|--memory)
            MEMORY_CHECK=true
            shift
            ;;
        -h|--help)
            echo "Usage: qtools refresh-data-workers [options]"
            echo ""
            echo "Restart all data worker services on the current node"
            echo ""
            echo "Options:"
            echo "  -h, --help    Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help to see available options"
            exit 1
            ;;
    esac
done

restart_data_workers() {
    bash -c "sudo systemctl stop ${QUIL_DATA_WORKER_SERVICE_NAME}@*"
    bash -c "sudo systemctl start ${QUIL_DATA_WORKER_SERVICE_NAME}@*"
}

if $MEMORY_CHECK; then
    memory_percentage=$(get_memory_percentage)
    echo "Current memory usage: ${memory_percentage}%"
    if (( $(echo "$memory_percentage > $THRESHOLD" | bc -l) )); then
        echo "Memory usage is greater than $THRESHOLD%, restarting data workers"
        restart_data_workers
    fi
else
    restart_data_workers
fi
