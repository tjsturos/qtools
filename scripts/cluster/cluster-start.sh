
DRY_RUN=false
DATA_WORKER_COUNT=$(yq eval ".service.clustering.local_data_worker_count" $QTOOLS_CONFIG_FILE)
LOCAL_ONLY=$(yq eval ".service.clustering.local_only" $QTOOLS_CONFIG_FILE)


LOCAL_IP=$(get_local_ip)

if [ "$DATA_WORKER_COUNT" == "null" ]; then
    DATA_WORKER_COUNT=$(nproc)
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
if ! [[ "$DATA_WORKER_COUNT" =~ ^[1-9][0-9]*$ ]] && [ "$(is_master)" == "false" ]; then
    echo "Error: --data-worker-count must be a positive integer ($DATA_WORKER_COUNT) on non-master nodes"
    exit 1
fi

echo -e "${BLUE}${INFO_ICON} [ $(if [ "$(is_master)" == "true" ]; then echo "MASTER"; else echo "SLAVE"; fi) ] [ $LOCAL_IP ] Found configuration for $DATA_WORKER_COUNT data workers${RESET}"


if [ "$(is_master)" == "true" ]; then
    if [ "$LOCAL_ONLY" == "true" ]; then
        echo -e "${BLUE}${INFO_ICON} Local only mode enabled, skipping remote server checks${RESET}"
    else
        if [ -f "$SSH_CLUSTER_KEY" ]; then
            echo -e "${GREEN}${CHECK_ICON} SSH key found: $SSH_CLUSTER_KEY${RESET}"
        else
            echo -e "${RED}${WARNING_ICON} SSH file: $SSH_CLUSTER_KEY not found!${RESET}"
        fi
        check_ssh_connections
        ssh_command_to_each_server "qtools cluster-start"
    fi
    # Check if master service is running
    if systemctl is-active $MASTER_SERVICE_NAME >/dev/null 2>&1; then
        echo -e "${BLUE}${INFO_ICON} Master service is running, restarting...${RESET}"
        # Wait for proof submission before restarting
        echo -e "${BLUE}${INFO_ICON} Waiting for current proof to complete...${RESET}"
        while read -r line; do
            if [[ $line =~ "submitting data proof" ]] || [[ $line =~ "workers not yet available for proving" ]]; then
                echo -e "${GREEN}${CHECK_ICON} Proof submission detected or workers not available, proceeding with restart${RESET}"
                break
            fi
        done < <(journalctl -u $MASTER_SERVICE_NAME -f -n 0)
        sudo systemctl restart $MASTER_SERVICE_NAME
    else
        echo -e "${BLUE}${INFO_ICON} Starting master service...${RESET}"
        sudo systemctl start $MASTER_SERVICE_NAME
    fi
else
    echo -e "${BLUE}${INFO_ICON} Not master node, skipping${RESET}"
fi

if [ "$DATA_WORKER_COUNT" -gt 0 ]; then
    start_local_data_worker_services 1 $DATA_WORKER_COUNT $LOCAL_IP
fi
