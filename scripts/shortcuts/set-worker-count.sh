#!/bin/bash
# HELP: Changes the number of workers for the Quilibrium service.
# USAGE: qtools set-worker-count
# PARAM: <number>: Set the number of workers (between 4 and the total number of CPU threads)
# PARAM: auto: Set the number of workers to automatic (default)
# PARAM: 0: Equivalent to 'auto'
# DESCRIPTION: This script allows you to change the number of workers for the Quilibrium service.
#              You can set it to a specific number (between 4 and the total number of CPU threads),
#              'auto', or '0' (which is equivalent to 'auto'). After changing, you'll need to
#              restart the Quilibrium service for the changes to take effect.

# Get the total number of CPU threads
total_threads=$(nproc)


if [ $# -ne 1 ]; then
    echo "Usage: qtools set-worker-count <number>"
    echo "       qtools set-worker-count auto"
    echo "       qtools set-worker-count 0"
    exit 1
fi

if [ "$1" == "auto" ] || [ "$1" == "0" ]; then
    yq -i 'del(.data_worker_service.worker_count)' $QUIL_CONFIG_FILE
    echo "Worker count reset to automatic"
else
    if ! [[ "$1" =~ ^[0-9]+$ ]]; then
        echo "Error: Worker count must be a positive integer"
        exit 1
    fi

    if [ "$1" -lt 4 ]; then
        echo "Error: Worker count must be at least 4"
        exit 1
    fi

    if [ "$1" -gt "$total_threads" ]; then
        echo "Error: Worker count cannot exceed number of CPU threads ($total_threads)"
        exit 1
    fi

    yq -i ".data_worker_service.worker_count = $1" $QTOOLS_CONFIG_FILE
    echo "Worker count set to $1"
fi


qtools restart
