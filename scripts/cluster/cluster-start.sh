
START_CORE_INDEX=$(yq eval '.service.clustering.local_core_start_index' $QTOOLS_CONFIG_FILE)
DATA_WORKER_COUNT=$(yq eval '.service.clustering.local_dataworker_count' $QTOOLS_CONFIG_FILE)
DRY_RUN=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --core-index-start)
            START_CORE_INDEX="$2"
            shift 2
            ;;
        --data-worker-count)
            DATA_WORKER_COUNT="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate START_CORE_INDEX
if ! [[ "$START_CORE_INDEX" =~ ^[0-9]+$ ]]; then
    echo "Error: --core-index-start must be a non-negative integer ($START_CORE_INDEX)"
    exit 1
fi

# Validate DATA_WORKER_COUNT
if ! [[ "$DATA_WORKER_COUNT" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: --data-worker-count must be a positive integer ($DATA_WORKER_COUNT)"
    exit 1
fi

# Adjust DATA_WORKER_COUNT if START_CORE_INDEX is 1
if [ "$START_CORE_INDEX" -eq 1 ]; then
    # Adjust MAX_CORES if START_CORE_INDEX is 1
    echo "Adjusting max cores available to $((MAX_CORES - 1)) (from $MAX_CORES) due to starting the master node on core 0"
    MAX_CORES=$((MAX_CORES - 1))
fi

# If DATA_WORKER_COUNT is greater than MAX_CORES, set it to MAX_CORES
if [ "$DATA_WORKER_COUNT" -gt "$MAX_CORES" ]; then
    DATA_WORKER_COUNT=$MAX_CORES
    echo "DATA_WORKER_COUNT adjusted down to maximum: $DATA_WORKER_COUNT"
fi

END_CORE_INDEX=$((START_CORE_INDEX + DATA_WORKER_COUNT))

# Loop through the data worker count and start each core

start_local_data_worker_services $START_CORE_INDEX $END_CORE_INDEX

if [ $START_CORE_INDEX -eq 1 ]; then
    if [ -f "$SSH_CLUSTER_KEY" ]; then
        echo -e "${GREEN}${CHECK_ICON} SSH key found: $SSH_CLUSTER_KEY${RESET}"
    else
        echo -e "${RED}${WARNING_ICON} SSH file: $SSH_CLUSTER_KEY not found!${RESET}"
    fi

    start_remote_server_services
    start_master_service
fi
