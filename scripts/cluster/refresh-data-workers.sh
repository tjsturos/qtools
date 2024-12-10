#!/bin/bash
# HELP: Will restart all data worker services on the current node.
#
# USAGE: qtools refresh-data-workers # Will restart all data worker services on the current node
# USAGE: qtools refresh-data-workers -m -t 80 # Check memory usage and restart data workers if memory usage is greater than the threshold 80\%
#
# OPTIONS:
# PARAM: -m, --memory    Check memory usage and restart data workers if memory usage is greater than the threshold
# PARAM: -t, --threshold Check memory usage and restart data workers if memory usage is greater than the threshold

MEMORY_CHECK=false
THRESHOLD=80
# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--threshold)
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

get_memory_percentage() {
    local total_memory=$(free | grep Mem | awk '{print $2}')
    local used_memory=$(free | grep Mem | awk '{print $3}')
    echo "scale=2; ($used_memory / $total_memory) * 100" | bc
}

restart_data_workers() {
    LOCAL_IP=$(get_local_ip)

    WORKER_COUNT=$(get_cluster_worker_count "$LOCAL_IP")

    echo "Found $WORKER_COUNT data workers for $LOCAL_IP"

    sudo systemctl stop ${QUIL_DATA_WORKER_SERVICE_NAME}@{1..$WORKER_COUNT}
    sudo systemctl start ${QUIL_DATA_WORKER_SERVICE_NAME}@{1..$WORKER_COUNT}
}


if $MEMORY_CHECK; then
    local memory_percentage=$(get_memory_percentage)
    echo "Current memory usage: ${memory_percentage}%"
    if [ $memory_percentage -gt $THRESHOLD ]; then
        echo "Memory usage is greater than $THRESHOLD%, restarting data workers"
        restart_data_workers
    fi
else
    restart_data_workers
fi
