#!/bin/bash
# HELP: Changes the number of workers for the Quilibrium service.
# USAGE: qtools set-worker-count
# PARAM: <number>: Set the number of workers (between 4 and the total number of CPU threads)
# PARAM: auto: Set the number of workers to automatic (default)
# PARAM: 0: Equivalent to 'auto'
# DESCRIPTION: This script allows you to change the number of workers for the Quilibrium service.
#              You can set it to a specific number (between 4 and the total number of CPU threads),
#              'auto', or '0' (which is equivalent to 'auto'). After changing, you'll need to
#              restart the Quilibrium service for the changes to take effect.

# Get the total number of CPU threads
total_threads=$(nproc)

# Get the current max_threads setting from the config file
current_setting=$(yq '.service.max_threads' "$QTOOLS_CONFIG_FILE")

# Function to compare current setting with input
compare_setting() {
    local input=$1
    if [[ $input == "auto" || $input == "0" ]]; then
        [[ $current_setting == "false" ]] && echo "same" || echo "different"
    elif [[ $input =~ ^[0-9]+$ ]]; then
        [[ $current_setting == "$input" ]] && echo "same" || echo "different"
    else
        echo "different"
    fi
}

# Check if input is provided as an argument
if [ $# -eq 0 ]; then
    read -p "Enter the number of workers (4-$total_threads), 'auto', or '0': " input
else
    input="$1"
fi

# Compare the input with the current setting
comparison=$(compare_setting "$input")

if [[ $comparison == "same" ]]; then
    echo "The requested setting is already in place. No changes needed."
    exit 0
fi

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
if [ $# -eq 0 ]; then
    read -p "Enter the number of workers (4-$total_threads), 'auto', or '0': " input
else
    input="$1"
fi

# Validate and process the input
result=$(validate_input "$input")

if [[ $result == "invalid" ]]; then
    echo "Invalid input. Please enter a number between 4 and $total_threads, 'auto', or '0'."
    exit 1
elif [[ $result == "false" ]] || [[ $result == "0" ]]; then
    yq -i '.service.max_threads = false' "$QTOOLS_CONFIG_FILE"
    echo "Max workers set to auto."
else
    yq -i ".service.max_threads = $result" "$QTOOLS_CONFIG_FILE"
    echo "Max workers set to $result."
fi

qtools update-service

qtools restart
