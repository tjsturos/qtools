#!/bin/bash
BLUE="\e[34m"
INFO_ICON="\u2139"
RESET="\e[0m"
DRY_RUN=false  # Set this to true for dry run mode

# Get the number of CPU cores
TOTAL_CORES=$(nproc)

# Set default values
DATA_WORKER_COUNT=$TOTAL_CORES
INDEX_START=1
MASTER=false
PARENT_PID=$$

# Function to display usage information
usage() {
    echo "Usage: $0 [--data-worker-count <number>] [--index-start <number>] [--master]"
    echo "  --data-worker-count  Number of workers to start (default: number of CPU cores)"
    echo "  --index-start        Starting index for worker cores (default: 1)"
    echo "  --master             Run a master node as one of this CPU's cores"
    exit 1
}

# Check if help is requested
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    usage
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --data-worker-count)
            DATA_WORKER_COUNT="$2"
            shift 2
            ;;
        --core-index-start)
            INDEX_START="$2"
            shift 2
            ;;
        --master)
            MASTER=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate COUNT
if ! [[ "$DATA_WORKER_COUNT" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: --data-worker-count must be a non-zero unsigned integer"
    exit 1
fi

# Adjust COUNT if master is specified, but only if not all cores are used for workers
if [ "$MASTER" == "true" ] && [ "$TOTAL_CORES" -eq "$DATA_WORKER_COUNT" ]; then
    DATA_WORKER_COUNT=$((TOTAL_CORES - 1))
fi

# Start the master and update the config
if [ "$MASTER" == "true" ]; then
    update_quil_config $DRY_RUN

    servers=$(yq eval '.service.clustering.servers' $QTOOLS_CONFIG_FILE)
    server_count=$(echo "$servers" | yq eval '. | length' -)

    for ((i=0; i<$server_count; i++)); do
        server=$(yq eval ".service.clustering.servers[$i]" $QTOOLS_CONFIG_FILE)
        ip=$(echo "$server" | yq eval '.ip' -)
        dataworker_count=$(echo "$server" | yq eval '.dataworker_count' -)
        index_start=$(echo "$server" | yq eval '.index_start' -)

        if ! echo "$(hostname -I)" | grep -q "$ip"; then
            if [ "$DRY_RUN" == "false" ]; then
                copy_quil_config_to_server $ip
                copy_qtools_config_to_server $ip
                setup_remote_cores "$ip" "$index_start" "$dataworker_count" &
            else
                echo -e "${BLUE}${INFO_ICON} [DRY RUN] Start cores on $ip with index start of $index_start and dataworker count of $dataworker_count${RESET}"
            fi
        fi
    done
else
    create_cluster_service_file $DATA_WORKER_COUNT $INDEX_START
fi

