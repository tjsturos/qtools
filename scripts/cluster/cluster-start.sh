
DRY_RUN=false
MAX_CORES=$(nproc)
DATA_WORKER_COUNT=$(yq eval '.service.clustering.data_worker_count' $QTOOLS_CONFIG_FILE)

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
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

# Validate DATA_WORKER_COUNT
if ! [[ "$DATA_WORKER_COUNT" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: --data-worker-count must be a positive integer ($DATA_WORKER_COUNT)"
    exit 1
fi

if [ "$(is_master)" == "true" ]; then
    # Adjust MAX_CORES if START_CORE_INDEX is 1
    echo "Adjusting max cores available to $((MAX_CORES - 1)) (from $MAX_CORES) due to starting the master node on core 0"
    MAX_CORES=$((MAX_CORES - 1))
fi

# If DATA_WORKER_COUNT is greater than MAX_CORES, set it to MAX_CORES
if [ "$DATA_WORKER_COUNT" -gt "$MAX_CORES" ]; then
    DATA_WORKER_COUNT=$MAX_CORES
    echo "DATA_WORKER_COUNT adjusted down to maximum: $DATA_WORKER_COUNT"
fi

start_local_data_worker_services 1 $DATA_WORKER_COUNT

if [ "$(is_master)" == "true" ]; then
    if [ -f "$SSH_CLUSTER_KEY" ]; then
        echo -e "${GREEN}${CHECK_ICON} SSH key found: $SSH_CLUSTER_KEY${RESET}"
    else
        echo -e "${RED}${WARNING_ICON} SSH file: $SSH_CLUSTER_KEY not found!${RESET}"
    fi

    check_ssh_connections

    ssh_command_to_each_server "qtools cluster-start"
    start_master_service
fi
