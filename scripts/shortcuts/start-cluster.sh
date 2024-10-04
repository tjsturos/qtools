START_CORE_INDEX=1
DATA_WORKER_COUNT=$(nproc)
PARENT_PID=$$
CRASHED=0

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
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done


# Validate START_CORE_INDEX
if ! [[ "$START_CORE_INDEX" =~ ^[0-9]+$ ]]; then
    echo "Error: --core-index-start must be a non-negative integer"
    exit 1
fi

# Validate DATA_WORKER_COUNT
if ! [[ "$DATA_WORKER_COUNT" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: --data-worker-count must be a positive integer"
    exit 1
fi

# Get the maximum number of CPU cores
MAX_CORES=$(nproc)

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


# Loop through the data worker count and start each core
start_cluster() {
    # Kill all node-* processes
    pkill node-*

    if [ $START_CORE_INDEX -eq 1 ]; then
        $QUIL_NODE_PATH/$NODE_BINARY &
        PARENT_PID=$!
    fi

    # start the master node
    for ((i=0; i<DATA_WORKER_COUNT; i++)); do
        CORE=$((START_CORE_INDEX + i))
        echo "Starting core $CORE"
        $QUIL_NODE_PATH/$NODE_BINARY --core $CORE --parent-process $PARENT_PID &
    done
}

is_parent_process_running() {
    ps -p $PARENT_PID > /dev/null 2>&1
    return $?
}

start_cores

while true
do
  if ! is_parent_process_running; then
    echo "Process crashed or stopped. restarting..."
	CRASHED=$(expr $CRASHED + 1)
    start_cores
  fi
  sleep 440
done


