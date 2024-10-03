#!/bin/bash
BLUE="\e[34m"
INFO_ICON="\u2139"
# Get the number of CPU cores
TOTAL_CORES=$(nproc)

# Set default values
DATA_WORKER_COUNT=$TOTAL_CORES
INDEX_START=1
MASTER=false

BINARY=$QUIL_NODE_PATH/$(get_versioned_binary)

# Function to create the systemd service file if it doesn't exist
create_service_file() {
    local service_file="/etc/systemd/system/quilibrium-dataworker@.service"
    if [ ! -f "$service_file" ]; then
        echo -e "${BLUE}${INFO_ICON} Creating quilibrium-dataworker@.service file...${RESET}"
        sudo tee "$service_file" > /dev/null <<EOF
[Unit]
Description=Quilibrium Ceremony Client Service

[Service]
Type=simple
Restart=always
RestartSec=5s
User=$USER
Group=$GROUP
WorkingDirectory=$QUIL_NODE_PATH
ExecStart=./$BINARY --core %i


[Install]
WantedBy=multi-user.target
EOF
        sudo systemctl daemon-reload
        echo -e "${BLUE}${INFO_ICON} Service file created and systemd reloaded.${RESET}"
    else
        echo -e "${BLUE}${INFO_ICON} quilibrium-dataworker@.service file already exists.${RESET}"
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

# Array to store background process PIDs
declare -a WORKER_PIDS

# Cleanup function to kill all worker processes
cleanup() {
    echo "Stopping all workers..."
    for core in "${WORKER_PIDS[@]}"; do
        sudo systemctl stop quilibrium-dataworker@$core.service
    done
    wait
    echo "All workers stopped"
    exit 0
}

# Set up trap for common termination signals
trap cleanup SIGINT SIGTERM SIGHUP

# Adjust COUNT if master is specified, but only if not all cores are used for workers
if [ "$MASTER" = true ] && [ "$TOTAL_CORES" -eq "$DATA_WORKER_COUNT" ]; then
    DATA_WORKER_COUNT=$((TOTAL_CORES - 1))
fi

MASTER_PID=false
# Start the master if specified
if [ "$MASTER" = true ]; then
    ./${BINARY} &> /dev/null &
    MASTER_PID=$!
    WORKER_PIDS+=($MASTER_PID)
fi

# Start the workers
for ((i=0; i<DATA_WORKER_COUNT; i++)); do
    CORE=$((INDEX_START + i))
    sudo systemctl enable quilibrium-dataworker@$CORE.service
    sudo systemctl start quilibrium-dataworker@$CORE.service
    
    WORKER_PIDS+=($CORE)
done

# Calculate the next start index
NEXT_START_INDEX=$((INDEX_START + DATA_WORKER_COUNT))

# Print hint for the next command
echo -e "\n${BLUE}${INFO_ICON} Hint for next command:${NC}"

# If master, configure data worker servers
if [ "$MASTER" = true ]; then
    # Read the config file
    config=$(yq eval . $QTOOLS_CONFIG_FILE)
    
    # Get the array of data worker only servers
    servers=$(echo "$config" | yq eval '.clustering.servers[]' -)
    
    # Clear the existing dataworkerMultiaddrs array
    yq eval -i '.engine.dataworkerMultiaddrs = []' "$QUIL_NODE_PATH/.config/config.yml"

    # Loop through each server
    for server in $servers; do

        # Get the IP address and dataworker count
        ip=$(echo "$server" | yq eval '.ip' -)
        dataworker_count=$(echo "$server" | yq eval '.dataworker_count // "false"' -)
        
        if echo "$(hostname -I)" | grep -q "$ip" && [ "$dataworker_count" == "false" ]; then
            # This is the master server, so subtract 1 from the total core count
            dataworker_count=$(($(nproc) - 1))
        else
            # Get the number of available cores
            available_cores=$(($(nproc) - 1))
            
            # Convert dataworker_count to integer and ensure it's not greater than available cores - 1
            dataworker_count=$(echo "$dataworker_count" | tr -cd '0-9')
            dataworker_count=$((dataworker_count > 0 ? dataworker_count : available_cores - 1))
            dataworker_count=$((dataworker_count < available_cores ? dataworker_count : available_cores - 1))
        fi

        # If dataworker_count is not a number, get it from the server
        if ! [[ "$dataworker_count" =~ ^[0-9]+$ ]]; then
            dataworker_count=$(ssh "$ip" nproc)
        fi
        
        # Create temporary YAML file with dataworkerMultiaddrs
        tmp_file=$(mktemp)
        echo "engine:" > "$tmp_file"
        echo "  dataworkerMultiaddrs:" >> "$tmp_file"
        for ((i=0; i<dataworker_count; i++)); do
            port=$((40000 + i))
            echo "    - /ip4/$ip/tcp/$port" >> "$tmp_file"
        done


        # Add dataworkerMultiaddrs to local config file
        yq eval-all -i 'select(fileIndex == 0) * select(fileIndex == 1)' "$QUIL_NODE_PATH/.config/config.yml" "$tmp_file"
        
        if ! echo "$(hostname -I)" | grep -q "$ip"; then
            # SCP the temporary file to the remote server
            scp -i ~/.ssh/cluster-key "$tmp_file" "$ip:$HOME/ceremonyclient/node/.config/config.yml"
        
            # Remove the temporary file
            rm "$tmp_file"
            
            # SCP the QTools config to the remote server
            scp -i ~/.ssh/cluster-key "$QTOOLS_CONFIG_FILE" "$ip:$HOME/qtools/config.yml"
        fi
    done
fi

