#!/bin/bash
# HELP: Will restart all data worker services on the current node.


# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
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


LOCAL_IP=$(get_local_ip)

WORKER_COUNT=$(get_cluster_worker_count "$LOCAL_IP")

echo "Found $WORKER_COUNT data workers for $LOCAL_IP"

sudo systemctl stop ${QUIL_DATA_WORKER_SERVICE_NAME}@{1..$WORKER_COUNT}
sudo systemctl start ${QUIL_DATA_WORKER_SERVICE_NAME}@{1..$WORKER_COUNT}