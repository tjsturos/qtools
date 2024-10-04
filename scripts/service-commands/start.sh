#!/bin/bash
# HELP: Starts the node application service. If .settings.debug is set to true or use --debug flag, this will start node in debug mode.
# PARAM: --debug: will start the node application in debug mode
# Usage: qtools start
# Usage: qtools start --quick
# TODO: qtools start --debug

# get settings
DEBUG_MODE="$(yq '.settings.debug' $QTOOLS_CONFIG_FILE)"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            DEBUG_MODE="true"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

IS_CLUSTERING_ENABLED=$(yq '.service.clustering.enabled // false' $QTOOLS_CONFIG_FILE)

if [ "$IS_CLUSTERING_ENABLED" == "true" ]; then
    CLUSTER_IPS=$(get_cluster_ips)
    echo "Cluster IPs: $CLUSTER_IPS"
    for ip in $CLUSTER_IPS; do
        if echo "$(hostname -I)" | grep -q "$ip"; then
            echo "Starting Quil on local server ($ip)"
            sudo systemctl start $QUIL_SERVICE_NAME.service
        else
            echo "Starting Quil on remote server $ip"
            ssh -i ~/.ssh/cluster-key "client@$ip" "sudo systemctl start $QUIL_SERVICE_NAME.service"
        fi
    done
else
    sudo systemctl start $QUIL_SERVICE_NAME.service
fi

