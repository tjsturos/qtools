#!/bin/bash
# Initialize variables
JSON_OUTPUT=false
REPORT_DATA=()

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Define colored icons
GREEN_CHECK="\e[32m✔\e[0m"
RED_CROSS="\e[31m✖\e[0m"
WARNING="\e[33m⚠\e[0m"
BLUE="\e[34m"
INFO_ICON="\u2139"
NC="\e[0m"

IS_CLUSTERING_ENABLED="$(yq '.service.clustering.enabled // false' $QTOOLS_CONFIG_FILE)"

if [ "$IS_CLUSTERING_ENABLED" == "true" ] && [ "$(is_master)" == "false" ]; then
    echo "Not the master node, skipping report."
    exit 0
fi

check_ports_status() {
    local PORTS_ACTUAL_OUTPUT="$(qtools ports-listening)"
    local ALL_PORTS_FUNCTIONAL=true
    local port_status=()
    while IFS= read -r LINE; do
        if [[ $LINE == *"was not found listening"* ]]; then
            PORT=$(echo $LINE | grep -oP '(?<=Port )\d+')
            port_status+=("Port $PORT is not working as expected")
            ALL_PORTS_FUNCTIONAL=false
        elif [[ $LINE == *"still starting up"* ]]; then
            PORT=$(echo $LINE | grep -oP '(?<=Port )\d+')
            port_status+=("$LINE")
            ALL_PORTS_FUNCTIONAL=false
        fi
    done <<< "$PORTS_ACTUAL_OUTPUT"

    if $ALL_PORTS_FUNCTIONAL; then
        if $JSON_OUTPUT; then
            REPORT_DATA+=("ports_status:All ports functional")
        else
            echo -e "${GREEN_CHECK} All ports functional"
        fi
    else
        if $JSON_OUTPUT; then
            REPORT_DATA+=("ports_status:${port_status[*]}")
        else
            for status in "${port_status[@]}"; do
                echo -e "${RED_CROSS} $status"
            done
        fi
    fi
}

check_hourly_reward_rate() {
    local HOURLY_REWARD_RATE=$(qtools hourly-reward-rate 3)

    if [[ $HOURLY_REWARD_RATE =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then
        if $JSON_OUTPUT; then
            REPORT_DATA+=("hourly_reward_rate:$HOURLY_REWARD_RATE")
        else
            echo -e "${GREEN_CHECK} Hourly reward rate: $HOURLY_REWARD_RATE"
        fi
    else
        if $JSON_OUTPUT; then
            REPORT_DATA+=("hourly_reward_rate:Invalid hourly reward rate: $HOURLY_REWARD_RATE")
        else
            echo -e "${RED_CROSS} Invalid hourly reward rate: $HOURLY_REWARD_RATE"
        fi
    fi
}

check_clustering_status() {
    local config_file="$QTOOLS_CONFIG_FILE"
    local enabled=$(yq '.service.clustering.enabled // false' "$config_file")

    if [[ "$enabled" == "true" ]]; then
        if $JSON_OUTPUT; then
            REPORT_DATA+=("clustering_status:enabled")
        else
            echo -e "${GREEN_CHECK} Clustering is enabled"
        fi
        local total_dataworkers=0
        local main_ip=$(yq '.service.clustering.main_ip' "$config_file")
        if [ "$(is_master)" == "true" ]; then
            if $JSON_OUTPUT; then
                REPORT_DATA+=("node_role:main")
                REPORT_DATA+=("main_ip:$main_ip")
            else
                echo -e "${GREEN_CHECK} This is the main clustering node (IP: $main_ip)"
            fi
            
            # Count total data workers across all servers
            # Read the config file
            config=$(yq eval . $QTOOLS_CONFIG_FILE)
            
            # Get the array of servers
            servers=$(echo "$config" | yq eval '.service.clustering.servers' -)

            # Get the number of servers
            server_count=$(echo "$servers" | yq eval '. | length' -)

            # Loop through each server
            for ((i=0; i<server_count; i++)); do
                server=$(echo "$servers" | yq eval ".[$i]" -)
                server_ip=$(echo "$server" | yq eval '.ip' -)
                dataworker_count=$(echo "$server" | yq eval '.dataworker_count // 0' -)

                if [[ "$dataworker_count" == "0" || "$dataworker_count" == "false" ]]; then
                    if [[ "$server_ip" == "$main_ip" ]]; then
                        dataworker_count=$(($(nproc) - 1))
                    else
                        dataworker_count=$(ssh -i ~/.ssh/cluster-key "client@$server_ip" nproc)
                    fi
                fi
                
                total_dataworkers=$((total_dataworkers + dataworker_count))
            done <<< "$servers"

            wait
            
            if $JSON_OUTPUT; then
                REPORT_DATA+=("total_dataworkers:$total_dataworkers")
            else
                echo -e "${INFO_ICON} Total data workers across all servers: $total_dataworkers"
            fi
        else
            if $JSON_OUTPUT; then
                REPORT_DATA+=("node_role:worker")
            else
                echo -e "${INFO_ICON} This is a worker node in the cluster"
            fi
            local dataworker_count=$(systemctl list-units --type=service --state=active | grep -c "$QUIL_SERVICE_NAME-dataworker@")
            if $JSON_OUTPUT; then
                REPORT_DATA+=("active_dataworkers:$dataworker_count")
            else
                echo -e "${INFO_ICON} Active data workers on this node: $dataworker_count"
            fi
        fi
    else
        if $JSON_OUTPUT; then
            REPORT_DATA+=("clustering_status:disabled")
        else
            echo -e "${INFO_ICON} Clustering is not enabled"
        fi
    fi
}

check_service_status() {
    local output=$(qtools status)

    if echo "$output" | grep -q "Active: active (running)"; then
        if $JSON_OUTPUT; then
            REPORT_DATA+=("node_service_status:Node service is running (active)")
        else
            echo -e "${GREEN_CHECK} Node service is running (active)"
        fi
        local version=$(qtools node-version)
        local uptime=$(echo "$output" | grep -oP '(?<=since ).*')
        if $JSON_OUTPUT; then
            REPORT_DATA+=("node_version:$version")
            REPORT_DATA+=("node_uptime:$uptime")
        else
            echo -e "${GREEN_CHECK} Node Version: $version"
            echo -e "${GREEN_CHECK} Node Uptime: $uptime"
        fi
    elif echo "$output" | grep -q "Active: inactive (dead)"; then
        if $JSON_OUTPUT; then
            REPORT_DATA+=("node_service_status:Node service is not running (dead)")
        else
            echo -e "${RED_CROSS} Node service is not running (dead)"
        fi
    elif echo "$output" | grep -q "Active: activating (auto-restart)"; then
        if $JSON_OUTPUT; then
            REPORT_DATA+=("node_service_status:Node is trying to restart (activating with auto-restart)")
        else
            echo -e "${WARNING} Node is trying to restart (activating with auto-restart)"
        fi
    else 
        if $JSON_OUTPUT; then
            REPORT_DATA+=("node_service_status:Unable to determine the status of the node")
        else
            echo -e "${RED_CROSS} Unable to determine the status of the node"
        fi
    fi

    # Check max_threads setting
    local max_threads=$(yq '.service.max_threads' $QTOOLS_CONFIG_FILE)
    local total_threads=$(nproc)
    
    if [[ $max_threads != "null" && $max_threads != "false" ]]; then
        if $JSON_OUTPUT; then
            REPORT_DATA+=("max_threads:Max threads is set to $max_threads/$total_threads.")
        else
            echo -e "${INFO_ICON} Max threads is set to $max_threads/$total_threads."
        fi
    fi
}

check_command_installed() {
    local command_name=$1
    local version_command=$2

    if command -v "$command_name" >/dev/null 2>&1; then
        message="$command_name is installed"
        if [[ -n $version_command ]]; then
            version=$($version_command)
            message+=" (version: $version)"
        fi
        if $JSON_OUTPUT; then
            REPORT_DATA+=("${command_name}_installed:$message")
        else
            echo -e "${GREEN_CHECK} $message"
        fi
    else
        if $JSON_OUTPUT; then
            REPORT_DATA+=("${command_name}_installed: $command_name is not installed")
        else
            echo -e "${RED_CROSS} $command_name is not installed"
        fi
    fi
}

check_unclaimed_balance() {
    local BALANCE=$(qtools unclaimed-balance)

    if [[ $BALANCE =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then
        if $JSON_OUTPUT; then
            REPORT_DATA+=("unclaimed_balance:$BALANCE")
        else
            echo -e "${GREEN_CHECK} Unclaimed balance: $BALANCE"
        fi
    else
        if [ ! -z "$(echo $BALANCE | grep 'finished starting')" ]; then
            if $JSON_OUTPUT; then
                REPORT_DATA+=("unclaimed_balance:App hasn't finished starting up-- can't fetch balance right now.")
            else
                echo -e "${WARNING} App hasn't finished starting up-- can't fetch balance right now."
            fi
        else
            if $JSON_OUTPUT; then
                REPORT_DATA+=("unclaimed_balance:Invalid unclaimed balance: $BALANCE")
            else
                echo -e "${RED_CROSS} Invalid unclaimed balance: $BALANCE"
            fi
        fi
    fi
}

check_peer_id() {
    local PEER_ID=$(qtools peer-id)

    if [[ -n $PEER_ID ]]; then
        if $JSON_OUTPUT; then
            REPORT_DATA+=("peer_id:$PEER_ID")
        else
            echo -e "${GREEN_CHECK} Peer ID: $PEER_ID"
        fi
    else
        if $JSON_OUTPUT; then
            REPORT_DATA+=("peer_id:Unable to retrieve Peer ID")
        else
            echo -e "${RED_CROSS} Unable to retrieve Peer ID"
        fi
    fi
}

check_frame_count() {
    local FRAME_COUNT=$(qtools frame-count)
    
    if [[ -n $FRAME_COUNT ]]; then
        if [ ! -z "$(echo $FRAME_COUNT | grep 'finished starting')" ]; then
            if $JSON_OUTPUT; then
                REPORT_DATA+=("frame_count:App hasn't finished starting up-- can't fetch frames right now.")
            else
                echo -e "${WARNING} App hasn't finished starting up-- can't fetch frames right now."
            fi
        else
            if $JSON_OUTPUT; then
                REPORT_DATA+=("frame_count:$FRAME_COUNT")
            else
                echo -e "${GREEN_CHECK} Frame Count: $FRAME_COUNT"
            fi
        fi
    else
        if $JSON_OUTPUT; then
            REPORT_DATA+=("frame_count:Unable to retrieve frame count")
        else
            echo -e "${RED_CROSS} Unable to retrieve frame count"
        fi
    fi
}

check_backup_status() {
    local config_file="$QTOOLS_CONFIG_FILE"
    local enabled=$(yq '.scheduled_tasks.backup.enabled' "$config_file" 2>/dev/null)

    if [[ "$enabled" == "true" ]]; then
        local node_backup_name=$(yq '.scheduled_tasks.backup.node_backup_name' "$config_file" 2>/dev/null)
        if [ -z "$node_backup_name" ]; then
            node_backup_name=$(qtools peer-id)
        fi
        local backup_url=$(yq '.scheduled_tasks.backup.backup_url' "$config_file" 2>/dev/null)
        local remote_user=$(yq '.scheduled_tasks.backup.remote_user' "$config_file" 2>/dev/null)
        local ssh_key_path=$(yq '.scheduled_tasks.backup.ssh_key_path' "$config_file" 2>/dev/null)
        local remote_backup_dir=$(yq '.scheduled_tasks.backup.remote_backup_dir' "$config_file" 2>/dev/null)

        if $JSON_OUTPUT; then
            REPORT_DATA+=("backup_status:Enabled")
            REPORT_DATA+=("node_backup_dir:$node_backup_dir")
            REPORT_DATA+=("backup_url:$backup_url")
            REPORT_DATA+=("remote_user:$remote_user")
            REPORT_DATA+=("ssh_key_path:$ssh_key_path")
            REPORT_DATA+=("remote_backup_dir:$remote_backup_dir")
        else
            echo -e "${GREEN_CHECK} Backup Status:"
            echo -e "    Enabled: $enabled"
            echo -e "    Node Backup Directory: $node_backup_dir"
            echo -e "    Backup URL: $backup_url"
            echo -e "    Remote User: $remote_user"
            echo -e "    SSH Key Path: $ssh_key_path"
            echo -e "    Remote Backup Directory: $remote_backup_dir"
        fi
    else
        if $JSON_OUTPUT; then
            REPORT_DATA+=("backup_status:Backups are not enabled")
        else
            echo -e "${RED_CROSS} Backups are not enabled"
        fi
    fi
}

check_proof_info() {
    local proof_info=$(source $QTOOLS_PATH/scripts/diagnostics/proof-info.sh)
    local storing_increment=$(echo "$proof_info" | grep STORING_INCREMENT | cut -d= -f2)
    local completed_increment=$(echo "$proof_info" | grep COMPLETED_INCREMENT | cut -d= -f2)
    local time_taken=$(echo "$proof_info" | grep TIME_TAKEN | cut -d= -f2)

    local proof_icon
    if (( completed_increment <= 100000 )); then
        proof_icon="🌧️"  # Just starting
    elif (( completed_increment <= 350000 )); then
        proof_icon="⛅"  # Intermediate, but not new
    elif (( completed_increment <= 500000 )); then
        proof_icon="🌤️"  # Intermediate
    elif (( completed_increment <= 700003 )); then
        proof_icon="☀️"  # Intermediate, experienced
    else
        proof_icon="🌈"  # Da bomb (best)
    fi

    if $JSON_OUTPUT; then
        REPORT_DATA+=("last_storing_proof_increment:$storing_increment")
        REPORT_DATA+=("last_completed_proof_increment:$completed_increment")
        REPORT_DATA+=("last_proof_completion_time:$time_taken seconds")
    else
        echo -e "${proof_icon} Last storing proof increment: $storing_increment"
        echo -e "${proof_icon} Last completed proof increment: $completed_increment"
        echo -e "${BLUE}${INFO_ICON}${NC} Last proof completion time: $time_taken seconds"
    fi
}

check_statistics_enabled() {
    local config_file="$QTOOLS_CONFIG_FILE"
    local enabled=$(yq '.scheduled_tasks.statistics.enabled' "$config_file")

    if [[ "$enabled" == "true" ]]; then
        if $JSON_OUTPUT; then
            REPORT_DATA+=("statistics_enabled:true")
        else
            echo -e "${GREEN_CHECK} Statistics are enabled"
        fi
    else
        if $JSON_OUTPUT; then
            REPORT_DATA+=("statistics_enabled:false")
        else
            echo -e "${RED_CROSS} Statistics are not enabled"
        fi
    fi
}

check_diagnostics_enabled() {
    local config_file="$QTOOLS_CONFIG_FILE"
    local enabled=$(yq '.scheduled_tasks.diagnostics.enabled' "$config_file" 2>/dev/null)

    if [[ "$enabled" == "true" ]]; then
        if $JSON_OUTPUT; then
            REPORT_DATA+=("diagnostics_enabled:true")
        else
            echo -e "${GREEN_CHECK} Diagnostics are enabled"
        fi
    else
        if $JSON_OUTPUT; then
            REPORT_DATA+=("diagnostics_enabled:false")
        else
            echo -e "${RED_CROSS} Diagnostics are not enabled"
        fi
    fi
}

check_auto_updates_enabled() {
    local config_file="$QTOOLS_CONFIG_FILE"
    local qtools_enabled=$(yq '.scheduled_tasks.updates.qtools.enabled' "$config_file")
    local node_enabled=$(yq '.scheduled_tasks.updates.node.enabled' "$config_file")
    local system_enabled=$(yq '.scheduled_tasks.updates.system.enabled' "$config_file")

    if [[ "$qtools_enabled" == "true" ]]; then
        if $JSON_OUTPUT; then
            REPORT_DATA+=("auto_updates_qtools_enabled:true")
        else
            echo -e "${GREEN_CHECK} Auto updates for qtools are enabled"
        fi
    else
        if $JSON_OUTPUT; then
            REPORT_DATA+=("auto_updates_qtools_enabled:false")
        else
            echo -e "${RED_CROSS} Auto updates for qtools are not enabled"
        fi
    fi

    if [[ "$node_enabled" == "true" ]]; then
        if $JSON_OUTPUT; then
            REPORT_DATA+=("auto_updates_node_enabled:true")
        else
            echo -e "${GREEN_CHECK} Auto updates for node are enabled"
        fi
    else
        if $JSON_OUTPUT; then
            REPORT_DATA+=("auto_updates_node_enabled:false")
        else
            echo -e "${RED_CROSS} Auto updates for node are not enabled"
        fi
    fi

    if [[ "$system_enabled" == "true" ]]; then
        if $JSON_OUTPUT; then
            REPORT_DATA+=("auto_updates_system_enabled:true")
        else
            echo -e "${GREEN_CHECK} Auto updates for system are enabled"
        fi
    else
        if $JSON_OUTPUT; then
            REPORT_DATA+=("auto_updates_system_enabled:false")
        else
            echo -e "${RED_CROSS} Auto updates for system are not enabled"
        fi
    fi
}

check_hardware_info() {
    local hardware_info=$($QTOOLS_PATH/scripts/diagnostics/hardware-info.sh)
    while IFS='|' read -r key value; do
        if $JSON_OUTPUT; then
            REPORT_DATA+=("${key}:${value}")
        else
            echo -e "${BLUE}${INFO_ICON}${NC} $key: $value"
        fi
    done <<< "$hardware_info"
}

escape_json_string() {
    local string="$1"
    string="${string//\\/\\\\}"  # Escape backslashes
    string="${string//\"/\\\"}"  # Escape double quotes
    string="${string//$/\\$}"    # Escape dollar signs
    string="${string//	/\\t}"   # Escape tabs
    string="${string//
/\\n}"   # Escape newlines
    string="${string//^M/\\r}"   # Escape carriage returns
    echo "$string"
}

to_snake_case() {
    local input="$1"
    # Convert to lowercase
    input="${input,,}"
    # Replace spaces and hyphens with underscores
    input="${input// /_}"
    input="${input//-/_}"
    # Remove any characters that are not alphanumeric or underscore
    input=$(echo "$input" | sed 's/[^a-z0-9_]//g')
    echo "$input"
}

status_report_json() {
     local json_input=""
    for item in "${REPORT_DATA[@]}"; do
        IFS=':' read -r key value <<< "$item"
        local snake_case_key=$(to_snake_case "$key")
        json_input+="$snake_case_key=$value\n"
    done

    echo -e "$json_input" | jq -R -s -c -M '
        split("\n")
        | map(select(length > 0))
        | map(split("="))
        | map({key: .[0], value: .[1:]|join("=")})
        | reduce .[] as $item ({}; .[$item.key] = $item.value)
    '
}

print_status_report() {
    check_peer_id
    check_proof_info
    check_frame_count
    check_ports_status
    check_service_status
    check_clustering_status
    check_command_installed "grpcurl"
    check_command_installed "go" "go version"
    check_command_installed "yq" "yq --version"
    check_hourly_reward_rate
    check_unclaimed_balance
    check_backup_status
    check_statistics_enabled
    check_diagnostics_enabled
    check_auto_updates_enabled
    check_hardware_info

    if $JSON_OUTPUT; then
        status_report_json
    fi
}

print_status_report