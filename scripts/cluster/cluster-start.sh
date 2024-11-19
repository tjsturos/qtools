
DRY_RUN=false
MAX_CORES=$(nproc)
DATA_WORKER_COUNT=$(yq eval ".service.clustering.local_data_worker_count" $QTOOLS_CONFIG_FILE)
LOCAL_IP=$(get_local_ip)

if [ "$DATA_WORKER_COUNT" == "null" ]; then
    DATA_WORKER_COUNT=$MAX_CORES
fi

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

echo -e "${BLUE}${INFO_ICON} Found configuration for $DATA_WORKER_COUNT data workers${RESET}"

if [ "$(is_master)" == "true" ]; then
    # Adjust MAX_CORES if START_CORE_INDEX is 1
    MAX_CORES=$((MAX_CORES - 1))
fi

# If DATA_WORKER_COUNT is greater than MAX_CORES, set it to MAX_CORES
if [ "$DATA_WORKER_COUNT" -gt "$MAX_CORES" ]; then
    DATA_WORKER_COUNT=$MAX_CORES
    echo "DATA_WORKER_COUNT adjusted down to maximum: $DATA_WORKER_COUNT"
fi

start_local_data_worker_services 1 $DATA_WORKER_COUNT $LOCAL_IP

if [ "$(is_master)" == "true" ]; then
    if [ -f "$SSH_CLUSTER_KEY" ]; then
        echo -e "${GREEN}${CHECK_ICON} SSH key found: $SSH_CLUSTER_KEY${RESET}"
    else
        echo -e "${RED}${WARNING_ICON} SSH file: $SSH_CLUSTER_KEY not found!${RESET}"
    fi

    check_ssh_connections

    ssh_command_to_each_server "qtools cluster-start"
    sudo systemctl start $MASTER_SERVICE_NAME
else
    echo -e "${BLUE}${INFO_ICON} Not master node, skipping${RESET}"
fi
