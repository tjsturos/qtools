#!/bin/bash

# Define colored icons
GREEN_CHECK="\e[32m✔\e[0m"
RED_CROSS="\e[31m✖\e[0m"
WARNING="\e[33m⚠\e[0m"
BLUE="\e[34m"
INFO_ICON="\u2139"
NC="\e[0m"

check_ports_status() {
    local PORTS_ACTUAL_OUTPUT="$(qtools ports-listening)"
    local ALL_PORTS_FUNCTIONAL=true
    while IFS= read -r LINE; do
        if [[ $LINE == *"was not found listening"* ]]; then
            PORT=$(echo $LINE | grep -oP '(?<=Port )\d+')
            echo -e "${RED_CROSS} Port $PORT is not working as expected"
            ALL_PORTS_FUNCTIONAL=false
        elif [[ $LINE == *"still starting up"* ]]; then
            PORT=$(echo $LINE | grep -oP '(?<=Port )\d+')
            echo -e "${WARNING} $LINE"
            ALL_PORTS_FUNCTIONAL=false
        fi
    done <<< "$PORTS_ACTUAL_OUTPUT"

    if $ALL_PORTS_FUNCTIONAL; then
        echo -e "${GREEN_CHECK} All ports functional"
    fi
}

check_hourly_reward_rate() {
    local HOURLY_REWARD_RATE=$(qtools hourly-reward-rate 5)

    if [[ $HOURLY_REWARD_RATE =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then
        echo -e "${GREEN_CHECK} Hourly reward rate: $HOURLY_REWARD_RATE"
    else
        echo -e "${RED_CROSS} Invalid hourly reward rate: $HOURLY_REWARD_RATE"
    fi
}

check_service_status() {
    local output=$(qtools status)

    if echo "$output" | grep -q "Active: active (running)"; then
        echo -e "${GREEN_CHECK} Node service is running (active)"
        local version=$(qtools node-version)
        local uptime=$(echo "$output" | grep -oP '(?<=since ).*')
        echo -e "${GREEN_CHECK} Node Version: $version"
        echo -e "${GREEN_CHECK} Node Uptime: $uptime"
    elif echo "$output" | grep -q "Active: inactive (dead)"; then
        echo -e "${RED_CROSS} Node service is not running (dead)"
    elif echo "$output" | grep -q "Active: activating (auto-restart)"; then
        echo -e "${WARNING} Node is trying to restart (activating with auto-restart)"
    else 
        echo -e "${RED_CROSS} Unable to determine the status of the node"
    fi
}

check_command_installed() {
    local command_name=$1
    local version_command=$2

    if command -v "$command_name" >/dev/null 2>&1; then
        message="${GREEN_CHECK} $command_name is installed"
        if [[ -n $version_command ]]; then
            version=$($version_command)
            message+=" (version: $version)"
        fi
        echo -e "$message"
    else
        echo -e "${RED_CROSS} $command_name is not installed"
    fi
}

check_unclaimed_balance() {
    local BALANCE=$(qtools unclaimed-balance)

    if [[ $BALANCE =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then
        echo -e "${GREEN_CHECK} Unclaimed balance: $BALANCE"
    else
        if [ ! -z "$(echo $BALANCE | grep 'finished starting')" ]; then
            echo -e "${WARNING} App hasn't finished starting up-- can't fetch balance right now."
        else
            echo -e "${RED_CROSS} Invalid unclaimed balance: $BALANCE"
        fi
    fi
}

check_peer_id() {
    local PEER_ID=$(qtools peer-id)

    if [[ -n $PEER_ID ]]; then
        echo -e "${GREEN_CHECK} Peer ID: $PEER_ID"
    else
        echo -e "${RED_CROSS} Unable to retrieve Peer ID"
    fi
}

check_frame_count() {
    local FRAME_COUNT=$(qtools frame-count)
    
    if [[ -n $FRAME_COUNT ]]; then
        if [ ! -z "$(echo $FRAME_COUNT | grep 'finished starting')" ]; then
            echo -e "${WARNING} App hasn't finished starting up-- can't fetch frames right now."
        else
            echo -e "${GREEN_CHECK} Frame Count: $FRAME_COUNT"
        fi
    else
        echo -e "${RED_CROSS} Unable to retrieve frame count"
    fi
}

check_backup_status() {
    local config_file="$QTOOLS_CONFIG_FILE"
    local enabled=$(yq '.settings.backups.enabled' "$config_file" 2>/dev/null || qyaml .settings.backups.enabled "$config_file")

    if [[ "$enabled" == "true" ]]; then
        local node_backup_dir=$(yq '.settings.backups.node_backup_dir' "$config_file" 2>/dev/null || qyaml '.settings.backups.node_backup_dir' "$config_file")
        local backup_url=$(yq '.settings.backups.backup_url' "$config_file" 2>/dev/null || qyaml '.settings.backups.backup_url' "$config_file")
        local remote_user=$(yq '.settings.backups.remote_user' "$config_file" 2>/dev/null || qyaml '.settings.backups.remote_user' "$config_file")
        local ssh_key_path=$(yq '.settings.backups.ssh_key_path' "$config_file" 2>/dev/null || qyaml '.settings.backups.ssh_key_path' "$config_file")
        local remote_backup_dir=$(yq '.settings.backups.remote_backup_dir' "$config_file" 2>/dev/null || qyaml '.settings.backups.remote_backup_dir' "$config_file")

        echo -e "${GREEN_CHECK} Backup Status:"
        echo -e "    Enabled: $enabled"
        echo -e "    Node Backup Directory: $node_backup_dir"
        echo -e "    Backup URL: $backup_url"
        echo -e "    Remote User: $remote_user"
        echo -e "    SSH Key Path: $ssh_key_path"
        echo -e "    Remote Backup Directory: $remote_backup_dir"
    else
        echo -e "${RED_CROSS} Backups are not enabled"
    fi
}

check_proof_info() {
    local proof_info=$($QTOOLS_PATH/scripts/diagnostics/proof-info.sh)
    local storing_increment=$(echo "$proof_info" | grep STORING_INCREMENT | cut -d= -f2)
    local completed_increment=$(echo "$proof_info" | grep COMPLETED_INCREMENT | cut -d= -f2)
    local time_taken=$(echo "$proof_info" | grep TIME_TAKEN | cut -d= -f2)

    echo -e "${BLUE}${INFO_ICON}${NC} Last storing proof increment: $storing_increment"
    echo -e "${BLUE}${INFO_ICON}${NC} Last completed proof increment: $completed_increment"
    echo -e "${BLUE}${INFO_ICON}${NC} Last proof completion time: $time_taken seconds"
}

check_hardware_info() {
    local hardware_info=$(./scripts/diagnostics/hardware-info.sh)
    while IFS='|' read -r key value; do
        echo -e "${BLUE}${INFO_ICON}${NC} $key: $value"
    done <<< "$hardware_info"
}

print_status_report() {
    check_peer_id
    check_frame_count
    check_ports_status
    check_service_status
    check_command_installed "grpcurl"
    check_command_installed "go" "go version"
    check_command_installed "yq" "yq --version"
    check_hourly_reward_rate
    check_unclaimed_balance
    check_backup_status
    check_hardware_info
    check_proof_info
}

print_status_report