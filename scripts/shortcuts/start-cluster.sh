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
    if [ "$DRY_RUN" = true ]; then
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
RestartSec=$(yq '.service.restart_time' $QTOOLS_CONFIG_FILE)
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

# Array to store background process PIDs
declare -a WORKER_PIDS

# Cleanup function to kill all worker processes
cleanup() {
    if [ "$DRY_RUN" = true ]; then
        echo -e "${BLUE}${INFO_ICON} [DRY RUN] Would stop all services${RESET}"
    else
        qtools stop
    fi
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
    if [ "$DRY_RUN" = true ]; then
        echo -e "${BLUE}${INFO_ICON} [DRY RUN] Would start $QUIL_SERVICE_NAME.service${RESET}"
    else
        echo -e "${BLUE}${INFO_ICON} Starting $QUIL_SERVICE_NAME.service${RESET}"
        sudo systemctl enable $QUIL_SERVICE_NAME.service
        sudo systemctl start $QUIL_SERVICE_NAME.service
    fi
fi

# Start the workers
for ((i=0; i<DATA_WORKER_COUNT; i++)); do
    CORE=$((INDEX_START + i))
    if [ "$DRY_RUN" = true ]; then
        echo -e "${BLUE}${INFO_ICON} [DRY RUN] Would enable and start $QUIL_SERVICE_NAME-dataworker@$CORE.service${RESET}"
    else
        sudo systemctl enable $QUIL_SERVICE_NAME-dataworker@$CORE.service
        if ! sudo systemctl start $QUIL_SERVICE_NAME-dataworker@$CORE.service; then
            echo "Failed to start $QUIL_SERVICE_NAME-dataworker@$CORE.service. Do you want to continue? (y/n)"
            read -r response
            if [[ "$response" =~ ^[Nn]$ ]]; then
                echo "Aborting..."
                exit 1
            fi
        else
            echo -e "\e[32mStarted $QUIL_SERVICE_NAME-dataworker@$CORE.service\e[0m"
        fi
    fi
done


# If master, configure data worker servers
if [ "$MASTER" == "true" ]; then
    # Read the config file
    config=$(yq eval . $QTOOLS_CONFIG_FILE)
    
    # Get the array of data worker only servers
    servers=$(echo "$config" | yq eval '.service.clustering.servers[]' -)
    
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
            dataworker_count=$(ssh -i ~/.ssh/cluster-key "$ip" nproc)
        fi

        
        
        # Increment the global count
        TOTAL_EXPECTED_DATAWORKERS=$((TOTAL_EXPECTED_DATAWORKERS + dataworker_count))

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
            echo "Copying dataworker config to $ip"
            scp -i ~/.ssh/cluster-key "$tmp_file" "$ip:$HOME/ceremonyclient/node/.config/config.yml"
        
            # Remove the temporary file
            rm "$tmp_file"
            
            echo "Copying QTools config to $ip"
            # SCP the QTools config to the remote server
            scp -i ~/.ssh/cluster-key "$QTOOLS_CONFIG_FILE" "$ip:$HOME/qtools/config.yml"
        fi
    done
    
    # Print out the number of dataworker multiaddrs
    actual_dataworkers=$(yq eval '.engine.dataworkerMultiaddrs | length' "$QUIL_NODE_PATH/.config/config.yml")

    echo -e "${BLUE}${INFO_ICON} Expected dataworker multiaddrs: $TOTAL_EXPECTED_DATAWORKERS${RESET}"
    echo -e "${BLUE}${INFO_ICON} Actual dataworker multiaddrs in config: $actual_dataworkers${RESET}"

    if [ "$TOTAL_EXPECTED_DATAWORKERS" -ne "$actual_dataworkers" ]; then
        echo -e "\e[33mWarning: The number of dataworker multiaddrs in the config doesn't match the expected count.\e[0m"
    fi
fi


# Add a final message for dry run
if [ "$DRY_RUN" = true ]; then
    echo -e "\n${BLUE}${INFO_ICON} Dry run completed. No actual changes were made.${RESET}"
fi

