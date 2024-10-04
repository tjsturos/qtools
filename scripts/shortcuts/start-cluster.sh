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

BINARY=$(get_versioned_node)

# Add this near the top of the script, after other variable declarations
TOTAL_EXPECTED_DATAWORKERS=0

# Function to create the systemd service file if it doesn't exist
create_service_file() {
    local service_file="/etc/systemd/system/$QUIL_SERVICE_NAME-dataworker@.service"
    if [ "$DRY_RUN" == "true" ]; then
        echo -e "${BLUE}${INFO_ICON} [DRY RUN] Would create $service_file if it doesn't exist${RESET}"
    else
        USER=$(whoami)
        GROUP=$(id -gn)
        if [ -z "$USER" ] || [ -z "$GROUP" ]; then
            echo "Error: Failed to get user or group information"
            exit 1
        fi
        echo -e "${BLUE}${INFO_ICON} Creating $QUIL_SERVICE_NAME-dataworker@.service file...${RESET}"
        sudo tee "$service_file" > /dev/null <<EOF
[Unit]
Description=Quilibrium Dataworker Service

[Service]
Type=simple
Restart=always
RestartSec=50ms
User=$USER
Group=$GROUP
WorkingDirectory=$(yq '.service.working_dir // "'$QUIL_NODE_PATH'"' $QTOOLS_CONFIG_FILE)
ExecStart=$QUIL_NODE_PATH/$BINARY --core %i


[Install]
WantedBy=multi-user.target
EOF
        sudo systemctl daemon-reload
        echo -e "${BLUE}${INFO_ICON} Service file created and systemd reloaded.${RESET}"
    fi
}

# Call the function to create the service file
create_service_file


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
        --index-start)
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

# Start the master if specified
if [ "$MASTER" == "true" ]; then
    if [ "$DRY_RUN" == "true" ]; then
        echo -e "${BLUE}${INFO_ICON} [DRY RUN] Would start $QUIL_SERVICE_NAME.service${RESET}"
    else
        echo -e "${BLUE}${INFO_ICON} Starting $QUIL_SERVICE_NAME.service${RESET}"
        sudo systemctl enable $QUIL_SERVICE_NAME.service
        sudo systemctl start $QUIL_SERVICE_NAME.service
    fi
fi

# Function to start a single core
start_core() {
    local CORE=$1
    if [ "$DRY_RUN" == "true" ]; then
        echo -e "${BLUE}${INFO_ICON} [DRY RUN] Would enable and start $QUIL_SERVICE_NAME-dataworker@$CORE.service${RESET}"
    else
        if ! sudo systemctl start $QUIL_SERVICE_NAME-dataworker@$CORE.service; then
            echo -e "\e[31mFailed to start $QUIL_SERVICE_NAME-dataworker@$CORE.service.\e[0m"
        else
            echo -e "\e[32mStarted $QUIL_SERVICE_NAME-dataworker@$CORE.service\e[0m"
            sudo systemctl enable $QUIL_SERVICE_NAME-dataworker@$CORE.service
        fi
    fi
}

start_remote_cores() {
    local IP=$1
    local CORE_INDEX_START=$2   
    echo -e "${BLUE}${INFO_ICON} Starting cluster's dataworkers on $IP${RESET}"
    ssh -i ~/.ssh/cluster-key "$IP" "qtools start-cluster --index-start $CORE_INDEX_START"
}

# Start the workers
for ((i=0; i<DATA_WORKER_COUNT; i++)); do
    CORE=$((INDEX_START + i))
    start_core $CORE &
done

# If master, configure data worker servers
if [ "$MASTER" == "true" ]; then
    # Read the config file
   
    config=$(yq eval . $QTOOLS_CONFIG_FILE)
    
    # Get the array of servers
    servers=$(echo "$config" | yq eval '.service.clustering.servers' -)

    # Clear the existing dataworkerMultiaddrs array
    yq eval -i '.engine.dataWorkerMultiaddrs = []' "$QUIL_CONFIG_FILE"

    # Initialize TOTAL_EXPECTED_DATAWORKERS
    TOTAL_EXPECTED_DATAWORKERS=0

    # Get the number of servers
    server_count=$(echo "$servers" | yq eval '. | length' -)

    SERVER_CORE_INDEX_START=1
    SERVER_CORE_INDEX_END=0
    # Loop through each server
    for ((i=0; i<server_count; i++)); do
        server=$(echo "$servers" | yq eval ".[$i]" -)
        ip=$(echo "$server" | yq eval '.ip' -)
        dataworker_count=$(echo "$server" | yq eval '.dataworker_count // "false"' -)
        
        # Skip invalid entries
        if [ -z "$ip" ] || [ "$ip" == "null" ]; then
            echo "Skipping invalid server entry: $server"
            continue
        fi

        echo "Processing server: $ip"
        echo "Server: $ip, Dataworker count: $dataworker_count"
        
        if echo "$(hostname -I)" | grep -q "$ip"; then
            yq eval -i ".service.clustering.main_ip = \"$ip\"" $QTOOLS_CONFIG_FILE
            echo "Set main IP to $ip in clustering configuration"
            # This is the master server, so subtract 1 from the total core count
            available_cores=$(($(nproc) - 1))
            if [ "$dataworker_count" == "false" ]; then
                dataworker_count=$(($(nproc) - 1))
            fi

            # Convert dataworker_count to integer and ensure it's not greater than available cores
            dataworker_count=$(echo "$dataworker_count" | tr -cd '0-9')
            dataworker_count=$((dataworker_count > 0 ? dataworker_count : available_cores))
            dataworker_count=$((dataworker_count < available_cores ? dataworker_count : available_cores))
        else
            # Get the number of available cores
            available_cores=$(ssh -i ~/.ssh/cluster-key "$ip" nproc)
            
            # Convert dataworker_count to integer and ensure it's not greater than available cores
            dataworker_count=$(echo "$dataworker_count" | tr -cd '0-9')
            dataworker_count=$((dataworker_count > 0 ? dataworker_count : available_cores))
            dataworker_count=$((dataworker_count < available_cores ? dataworker_count : available_cores))
        fi

        echo "Dataworker count for $ip: $dataworker_count"
        
        # Increment the global count
        TOTAL_EXPECTED_DATAWORKERS=$((TOTAL_EXPECTED_DATAWORKERS + dataworker_count))

        # Create temporary YAML file with dataworkerMultiaddrs
        tmp_file=$(mktemp)
        echo "engine:" > "$tmp_file"
        echo "  dataWorkerMultiaddrs:" >> "$tmp_file"
        for ((j=0; j<dataworker_count; j++)); do
            port=$((40000 + j + SERVER_CORE_INDEX_START))
            echo "    - /ip4/$ip/tcp/$port" >> "$tmp_file"
            SERVER_CORE_INDEX_END=$((SERVER_CORE_INDEX_END + 1))
        done

        # Add dataworkerMultiaddrs to local config file
        yq eval-all -i '(select(fileIndex == 0) *?+ select(fileIndex == 1)) as $merged | select(fileIndex == 0) *? $merged' "$QUIL_CONFIG_FILE" "$tmp_file"
        
        if ! echo "$(hostname -I)" | grep -q "$ip"; then
            # SCP the temporary file to the remote server
            echo "Copying dataworker config to $ip"
            if [ "$DRY_RUN" == "false" ]; then
                # Ensure the destination directory exists on the remote server
                ssh -i ~/.ssh/cluster-key "$ip" "mkdir -p $HOME/ceremonyclient/node/.config"
                scp -i ~/.ssh/cluster-key "$QUIL_CONFIG_FILE" "$ip:$HOME/ceremonyclient/node/.config/config.yml"
            else
                echo "Dry run, skipping copying dataworker config to $ip"
            fi
            
            echo "Copying QTools config to $ip"
            # SCP the QTools config to the remote server
            if [ "$DRY_RUN" == "false" ]; then
                scp -i ~/.ssh/cluster-key "$QTOOLS_CONFIG_FILE" "$ip:$HOME/qtools/config.yml"
                start_remote_cores "$ip" "$SERVER_CORE_INDEX_START" &
            else
                log "Dry run, skipping starting qtools config on $ip"
                log "Going to start $dataworker_count dataworkers on $ip with core index start $SERVER_CORE_INDEX_START"
            fi
        fi

        rm "$tmp_file"
        SERVER_CORE_INDEX_START=$((SERVER_CORE_INDEX_END + 1))
    done

    # Print out the number of dataworker multiaddrs
    actual_dataworkers=$(yq eval '.engine.dataWorkerMultiaddrs | length' "$QUIL_CONFIG_FILE")

    if [ "$TOTAL_EXPECTED_DATAWORKERS" -ne "$actual_dataworkers" ]; then
        echo -e "\e[33mWarning: The number of dataworker multiaddrs in the config doesn't match the expected count.\e[0m"
        echo -e "${BLUE}${INFO_ICON} Dataworkers to be started: $TOTAL_EXPECTED_DATAWORKERS${RESET}"
        echo -e "${BLUE}${INFO_ICON} Actual dataworker multiaddrs in config: $actual_dataworkers${RESET}"
    else
        echo -e "${BLUE}${INFO_ICON} Number of actual dataworkers found ($actual_dataworkers) matches the expected amount.${RESET}"
    fi
fi


# Add a final message for dry run
if [ "$DRY_RUN" == "true" ]; then
    echo -e "\n${BLUE}${INFO_ICON} Dry run completed. No actual changes were made.${RESET}"
fi
