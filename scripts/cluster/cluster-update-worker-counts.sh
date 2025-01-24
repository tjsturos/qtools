#!/bin/bash

# Default values
WORKER_COUNT=""
CORES_TO_USE=""
FILTERS=()

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --workers)
            WORKER_COUNT="$2"
            shift 2
            ;;
        --cores)
            CORES_TO_USE="$2" 
            shift 2
            ;;
        --filter)
            # Split filter on | if present, otherwise add single filter
            if [[ "$2" == *"|"* ]]; then
                IFS="|" read -ra FILTER_ARRAY <<< "$2"
                FILTERS+=("${FILTER_ARRAY[@]}")
            else
                FILTERS+=("$2")
            fi
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: qtools cluster-update-worker-counts [--workers COUNT] [--cores COUNT] [--filter STRING] [--filter STRING]..."
            exit 1
            ;;
    esac
done

if [ -z "$WORKER_COUNT" ] && [ -z "$CORES_TO_USE" ]; then
    echo "Error: Must specify at least one of --workers or --cores"
    exit 1
fi

# Get server configuration
config=$(yq eval . $QTOOLS_CONFIG_FILE)
servers=$(echo "$config" | yq eval '.service.clustering.servers' -)
server_count=$(echo "$servers" | yq eval '. | length' -)

# Loop through servers
for ((i=0; i<server_count; i++)); do
    server=$(echo "$servers" | yq eval ".[$i]" -)
    server_ip=$(echo "$server" | yq eval '.ip' -)
    hardware_info=$(echo "$server" | yq eval '.hardware_info // ""' -)

    # Skip if filters are set and hardware_info is blank/unset
    if [ ${#FILTERS[@]} -gt 0 ] && [ -z "$hardware_info" ]; then
        echo "Skipping $server_ip (hardware info is blank)"
        continue
    fi

    # Check if hardware_info matches any of the filters
    matches_filter=false
    if [ ${#FILTERS[@]} -eq 0 ]; then
        matches_filter=true
    else
        for filter in "${FILTERS[@]}"; do
            if [[ "$hardware_info" =~ $filter ]]; then
                matches_filter=true
                break
            fi
        done
    fi

    if ! $matches_filter; then
        echo "Skipping $server_ip (hardware info doesn't match any filter)"
        continue
    fi

    echo "Updating server $server_ip..."

    # Update worker count if specified
    if [ -n "$WORKER_COUNT" ]; then
        yq eval -i ".service.clustering.servers[$i].data_worker_count = $WORKER_COUNT" $QTOOLS_CONFIG_FILE
        echo "Set worker count to $WORKER_COUNT"
    fi

    # Update cores if specified
    if [ -n "$CORES_TO_USE" ]; then
        yq eval -i ".service.clustering.servers[$i].cores_to_use = $CORES_TO_USE" $QTOOLS_CONFIG_FILE
        echo "Set cores to use to $CORES_TO_USE"
    fi
done

echo "Worker count updates complete"
