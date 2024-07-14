#!/bin/bash

# Define colored icons
GREEN_CHECK="\e[32m✔\e[0m"  # Green check mark
RED_CROSS="\e[31m✖\e[0m"    # Red cross mark

check_ports_status() {
    local PORTS_ACTUAL_OUTPUT="$(qtools ports-listening)"
    local ALL_PORTS_FUNCTIONAL=true
    while IFS= read -r LINE; do
        if [[ $LINE == *"was not found listening"* ]]; then
            # Extract the port number from the line
            PORT=$(echo $LINE | grep -oP '(?<=Port )\d+')
            echo "${RED_CROSS} Port $PORT is not working as expected"
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
        echo -e "${GREEN_CHECK} Node is running"

        # Extract and display the version and uptime
        local version=$(qtools node-version)
        local uptime=$(echo "$output" | grep -oP '(?<=since ).*(?=;)')
        echo -e "${GREEN_CHECK} Version: $version"
        echo -e "${GREEN_CHECK} Uptime: $uptime"
    elif echo "$output" | grep -q "Active: inactive (dead)"; then
        echo -e "${RED_CROSS} Node is not running"
    else
        echo -e "Unable to determine the status of the node"
    fi
}

check_command_installed() {
    local command_name=$1
    local version_command=$2

    if command -v "$command_name" >/dev/null 2>&1; then
        echo -e "${GREEN_CHECK} $command_name is installed"
        if [[ -n $version_command ]]; then
            local version=$($version_command)
            echo -e "${GREEN_CHECK} $command_name version: $version"
        fi
    else
        echo -e "${RED_CROSS} $command_name is not installed"
    fi
}

check_unclaimed_balance() {
    local BALANCE=$(qtools unclaimed-balance)

    if [[ $BALANCE =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then
        echo -e "${GREEN_CHECK} Unclaimed balance: $BALANCE"
    else
        echo -e "${RED_CROSS} Invalid unclaimed balance: $BALANCE"
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
    local PEER_ID=$(qtools frame-count)

    if [[ -n $PEER_ID ]]; then
        echo -e "${GREEN_CHECK} Frame Count: $PEER_ID"
    else
        echo -e "${RED_CROSS} Unable to retrieve frame count"
    fi
}

check_backup_status() {
    local config_file="$QTOOLS_CONFIG_FILE"
    local enabled
    local node_backup_dir
    local backup_url
    local remote_user
    local ssh_key_path
    local remote_backup_dir

    if command -v yq >/dev/null 2>&1; then
        enabled=$(yq '.settings.backups.enabled' "$config_file")
    else
        enabled=$(qyaml .settings.backups.enabled "$config_file")
    fi

    if [[ "$enabled" == "true" ]]; then
        if command -v yq >/dev/null 2>&1; then
            node_backup_dir=$(yq '.settings.backups.node_backup_dir' "$config_file")
            backup_url=$(yq '.settings.backups.backup_url' "$config_file")
            remote_user=$(yq '.settings.backups.remote_user' "$config_file")
            ssh_key_path=$(yq '.settings.backups.ssh_key_path' "$config_file")
            remote_backup_dir=$(yq '.settings.backups.remote_backup_dir' "$config_file")
        else
            node_backup_dir=$(qyaml '.settings.backups.node_backup_dir' "$config_file")
            backup_url=$(qyaml '.settings.backups.backup_url' "$config_file")
            remote_user=$(qyaml '.settings.backups.remote_user' "$config_file")
            ssh_key_path=$(qyaml '.settings.backups.ssh_key_path' "$config_file")
            remote_backup_dir=$(qyaml '.settings.backups.remote_backup_dir' "$config_file")
        fi

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

check_peer_id
check_frame_count
check_ports_status
check_service_status "ceremonyclient@main.service"
check_command_installed "grpcurl"
check_command_installed "go" "go version"
check_command_installed "yq" "yq --version"
check_hourly_reward_rate
check_unclaimed_balance
check_backup_status