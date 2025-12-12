# Parse command line arguments
NEW_MODE=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --on)
            NEW_MODE="true"
            shift
            ;;
        --off)
            NEW_MODE="false"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: qtools toggle-memory-check [--on|--off]"
            exit 1
            ;;
    esac
done

IS_CLUSTERING_ENABLED=$(yq '.service.clustering.enabled // false' $QTOOLS_CONFIG_FILE)

if [ "$IS_CLUSTERING_ENABLED" == "false" ]; then
    echo "Cluster mode is not enabled, skipping"
    exit 1
fi

# If no flag provided, toggle current value
if [ -z "$NEW_MODE" ]; then
    CURRENT_MODE=$(yq '.scheduled_tasks.cluster.memory_check.enabled // false' $QTOOLS_CONFIG_FILE)
    if [ "$CURRENT_MODE" == "true" ]; then
        NEW_MODE="false"
    else
        NEW_MODE="true"
    fi
fi

# Update the config file
qtools config set-value scheduled_tasks.cluster.memory_check.enabled "$NEW_MODE" --quiet

log "Cluster memory check has been set to: $NEW_MODE"
