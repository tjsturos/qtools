#!/bin/bash
# HELP: Changes the number of workers for the Quilibrium service.
# USAGE: qtools change-worker-count
# PARAM: <number>: Set the number of workers (between 4 and the total number of CPU threads)
# PARAM: auto: Set the number of workers to automatic (default)
# PARAM: 0: Equivalent to 'auto'
# DESCRIPTION: This script allows you to change the number of workers for the Quilibrium service.
#              You can set it to a specific number (between 4 and the total number of CPU threads),
#              'auto', or '0' (which is equivalent to 'auto'). After changing, you'll need to
#              restart the Quilibrium service for the changes to take effect.

# Get the total number of CPU threads
total_threads=$(nproc)

# Function to validate input
validate_input() {
    local input=$1
    if [[ $input == "auto" || $input == "0" ]]; then
        echo "false"
    elif [[ $input =~ ^[0-9]+$ && $input -ge 4 && $input -le $total_threads ]]; then
        echo "$input"
    else
        echo "invalid"
    fi
}

# Prompt for input
read -p "Enter the number of workers (4-$total_threads), 'auto', or '0': " input

# Validate and process the input
result=$(validate_input "$input")

if [[ $result == "invalid" ]]; then
    echo "Invalid input. Please enter a number between 4 and $total_threads, 'auto', or '0'."
    exit 1
elif [[ $result == "false" ]] || [[ $result == "0" ]]; then
    yq -i '.service.max_workers = false' "$QTOOLS_CONFIG_FILE"
    echo "Max workers set to auto."
else
    yq -i ".service.max_workers = $result" "$QTOOLS_CONFIG_FILE"
    echo "Max workers set to $result."
fi

qtools stop --quick

qtools update-service

qtools start --quick
