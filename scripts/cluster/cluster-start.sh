#!/bin/bash

# Source helper functions
source $QTOOLS_PATH/scripts/cluster/service-helpers.sh

DRY_RUN=false
CORES_TO_USE=$(yq eval ".service.clustering.local_data_worker_count" $QTOOLS_CONFIG_FILE)
LOCAL_ONLY=$(yq eval ".service.clustering.local_only" $QTOOLS_CONFIG_FILE)
IMMEDIATE_RESTART=true

LOCAL_IP=$(get_local_ip)

if [ "$CORES_TO_USE" == "false" ] || [ -z "$CORES_TO_USE" ]; then
    CORES_TO_USE=$(get_worker_count)
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --cores-to-use)
            CORES_TO_USE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --wait)
            IMMEDIATE_RESTART=false
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate DATA_WORKER_COUNT
if ! [[ "$CORES_TO_USE" =~ ^[1-9][0-9]*$ ]] && [ "$(is_master)" == "false" ]; then
    echo -e "${RED}${ERROR_ICON} [ $(if [ "$(is_master)" == "true" ]; then echo "MASTER"; else echo "SLAVE"; fi) ] [ $LOCAL_IP ] Error: --cores-to-use must be a positive integer ($CORES_TO_USE) on non-master nodes${RESET}"
    exit 1
fi

echo -e "${BLUE}${INFO_ICON} [ $(if [ "$(is_master)" == "true" ]; then echo "MASTER"; else echo "SLAVE"; fi) ] [ $LOCAL_IP ] Found configuration for $CORES_TO_USE cores to use${RESET}"

# Master node coordination
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

    # Start/restart master service with wait logic
    if systemctl is-active $MASTER_SERVICE_NAME >/dev/null 2>&1; then
        echo -e "${BLUE}${INFO_ICON} Master service is running, restarting...${RESET}"
        if [ "$IMMEDIATE_RESTART" == "false" ]; then
            echo -e "${BLUE}${INFO_ICON} Waiting for current proof to complete...${RESET}"
            while read -r line; do
                if [[ $line =~ "submitting data proof" ]] || [[ $line =~ "workers not yet available for proving" ]]; then
                    echo -e "${GREEN}${CHECK_ICON} Proof submission detected or workers not available, proceeding with restart${RESET}"
                    break
                fi
            done < <(journalctl -u $MASTER_SERVICE_NAME -f -n 0)
        fi
        sudo systemctl restart $MASTER_SERVICE_NAME
    else
        start_master_service
    fi
fi

# Start local workers using base_index from config
if [ "$CORES_TO_USE" -gt 0 ]; then
    local base_index=$(get_base_index_for_server)
    local start_index=$base_index
    local end_index=$((start_index + CORES_TO_USE - 1))
    start_local_data_worker_services $start_index $end_index $LOCAL_IP
fi
