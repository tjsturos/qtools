is_master() {
    MAIN_IP=$(yq '.service.clustering.main_ip' $QTOOLS_CONFIG_FILE)
    if echo "$(hostname -I)" | grep -q "$MAIN_IP"; then
        echo "true"
    else
        echo "false"
    fi
}

get_cluster_server_info() {
    local servers=$(yq eval '.service.clustering.servers' $QTOOLS_CONFIG_FILE)
    local server_count=$(echo "$servers" | yq eval '. | length' -)
    local current_ip=false
    local current_dataworker_count=0
    local current_index_start=0

    for ((i=0; i<$server_count; i++)); do
        local server=$(yq eval ".service.clustering.servers[$i]" $QTOOLS_CONFIG_FILE)
        local ip=$(echo "$server" | yq eval '.ip' -)
        local dataworker_count=$(echo "$server" | yq eval '.dataworker_count' -)
        local index_start=$(echo "$server" | yq eval '.index_start' -)

        if echo "$(hostname -I)" | grep -q "$ip"; then
            current_ip=$ip
            current_dataworker_count=$dataworker_count
            current_index_start=$index_start
        fi
    done
    echo "$current_ip $current_dataworker_count $current_index_start"
}

