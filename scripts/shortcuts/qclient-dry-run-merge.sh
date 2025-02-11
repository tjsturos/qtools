
#!/bin/bash

# Check if any parameters were provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <folder1> <folder2> ..."
    exit 1
fi

# Initialize an empty array to store the folder paths
folders=()

# Loop through all provided parameters
for folder in "$@"; do
    # Construct the full path and add it to the array
    folders+=("$QUIL_NODE_PATH/$folder/.config/")
done

# Change directory to the client path
cd $QUIL_CLIENT_PATH

# Function to run merge and extract score
run_merge() {
    local folders=("$@")
    local output=$(./qclient-2.0.0.2-$OS_ARCH config prover merge $QUIL_NODE_PATH/.config/ "${folders[@]}" --dry-run --config $QUIL_NODE_PATH/.config)
    local score=$(echo "$output" | grep "Effective seniority score:" | awk '{print $NF}')
    echo "$score"
}

# Log function
log_result() {
    local folders=("$@")
    local score=$1
    shift
    echo -e "Folders: ${folders[*]} - Score: $score"
}

# Loop through increasing number of folders
for ((num_folders=1; num_folders<=${#folders[@]}; num_folders++)); do
    # Use combination to generate all possible combinations of folders

    selected_folders=()
    for ((i=0; i<num_folders; i++)); do
        selected_folders+=("${folders[i]}")
    done
    echo -e "Command used:\n./qclient-2.0.0-$OS_ARCH config prover merge $QUIL_NODE_PATH/.config/ "${selected_folders[@]}" --dry-run"
    score=$(run_merge "${selected_folders[@]}")
    log_result "$score" "${selected_folders[@]}"
 
done

