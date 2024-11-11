#!/bin/bash

# HELP: Views the logs for the node application.

IS_CLUSTERING_ENABLED="$(yq '.service.clustering.enabled' $QTOOLS_CONFIG_FILE)"
FILTER_TEXT=""
CORE_ID=false
LINES=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --core)
            if [[ -n $2 && $2 =~ ^[0-9]+$ ]]; then
                CORE_ID=$2
                echo "Viewing logs for data worker core $CORE_ID:"
                sudo journalctl -u $QUIL_SERVICE_NAME-dataworker@$CORE_ID -f --no-hostname -o cat
                exit 0
            else
                echo "Error: --core option requires a valid numeric core ID"
                exit 1
            fi
            ;;
        -n)
            LINES=$2
            shift
            ;;
        --filter)
            FILTER_TEXT=$2
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
    shift
done

if [ "$IS_CLUSTERING_ENABLED" == "true" ]; then
    if [ "$CORE_ID" == "false" ]; then
        sudo journalctl -u $QUIL_SERVICE_NAME -f --no-hostname -o cat ${FILTER_TEXT:+--grep="$FILTER_TEXT"} ${LINES:+-n=$LINES}
    else
        sudo journalctl -u dataworker@$CORE_ID -f --no-hostname -o cat ${FILTER_TEXT:+--grep="$FILTER_TEXT"} ${LINES:+-n=$LINES}
    fi
else
    sudo journalctl -u $QUIL_SERVICE_NAME -f --no-hostname -o cat ${FILTER_TEXT:+--grep="$FILTER_TEXT"} ${LINES:+-n=$LINES}
fi
