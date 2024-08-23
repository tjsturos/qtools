#!/bin/bash

# Set up temporary log file
temp_log_file=$(mktemp)
error_log_dir="$QTOOLS_PATH/errors"
mkdir -p "$error_log_dir"

# Function to run a diagnostic script and log output
run_diagnostic() {
    local script="$1"
    echo "Running diagnostic: $script" | tee -a "$temp_log_file"
    qtools $script 2>&1 | tee -a "$temp_log_file"
    echo | tee -a "$temp_log_file"
    return ${PIPESTATUS[0]}
}

# Main function to run all diagnostics
run_all_diagnostics() {
    echo "Starting diagnostics..." | tee -a "$temp_log_file"
    echo | tee -a "$temp_log_file"

    # Check service status first
    run_diagnostic "check-service-status"
    service_status=$?

    # Always check CPU load, ports, and qclient
    run_diagnostic "check-cpu-load"
    run_diagnostic "ports-listening"
    run_diagnostic "check-qclient"

    # If service is not running, perform additional checks
    if [ $service_status -ne 0 ]; then
        run_diagnostic "check-node-files"
        run_diagnostic "verify-backup-integrity"
        run_diagnostic "check-disk-space.sh"
        run_diagnostic "check-network-connectivity"
    fi

    echo "Diagnostics completed." | tee -a "$temp_log_file"
}

# Function to run specified tests
run_specified_tests() {
    echo "Starting specified diagnostics..." | tee -a "$temp_log_file"
    echo | tee -a "$temp_log_file"

    for test in "${tests[@]}"; do
        run_diagnostic "$test"
    done

    echo "Specified diagnostics completed." | tee -a "$temp_log_file"
}

# Initialize an array to store specified tests
tests=()

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --test)
            tests+=("$2")
            shift 2
            ;;
        *)
            echo "Unknown option: $1" | tee -a "$temp_log_file"
            exit 1
            ;;
    esac
done

# Run specified tests if any, otherwise run all diagnostics
if [ ${#tests[@]} -gt 0 ]; then
    run_specified_tests
else
    run_all_diagnostics
fi

# Check if there were any errors in the log
if grep -q -E "error|Error|ERROR" "$temp_log_file"; then
    error_log_file="$error_log_dir/log_$(date +%Y%m%d_%H%M%S).txt"
    mv "$temp_log_file" "$error_log_file"
    echo "Errors detected. Log file saved to: $error_log_file"
else
    # Clean up temporary log file if no errors
    rm "$temp_log_file"
fi