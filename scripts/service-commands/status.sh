#!/bin/bash
# HELP: Gets the node application service\'s current status.
# Usage: qtools status

IS_CLUSTERING_ENABLED=$(yq '.service.clustering.enabled // false' $QTOOLS_CONFIG_FILE)
IS_ORCHESTRATOR=$(hostname) == $(yq '.service.clustering.orchestrator_hostname // ""' $QTOOLS_CONFIG_FILE)

if [ "$IS_CLUSTERING_ENABLED" == "true" ]; then
    if [ "$IS_ORCHESTRATOR" == "true" ]; then
        echo "Orchestrator node detected. Disabling peripheral services."
        sudo systemctl status $QUIL_SERVICE_NAME.service --no-pager
    fi

    HAS_DATA_WORKERS=$(yq '.service.clustering.has_data_workers' $QTOOLS_CONFIG_FILE)
    if [ "$HAS_DATA_WORKERS" == "true" ]; then
        echo "Data worker node detected. Disabling peripheral services."
        DATA_WORKER_COUNT=$(yq '.service.clustering.data_worker_count' $QTOOLS_CONFIG_FILE)
        DATA_WORKER_INDEX_START=$(yq '.service.clustering.data_worker_index_start' $QTOOLS_CONFIG_FILE)
        for ((i=$DATA_WORKER_INDEX_START; i<$DATA_WORKER_COUNT; i++)); do
            echo "Status for data worker $i:"
            sudo systemctl status $QUIL_SERVICE_NAME-$i.service --no-pager
            echo ""
        done
    fi
else
    sudo systemctl status $QUIL_SERVICE_NAME.service --no-pager
fi
