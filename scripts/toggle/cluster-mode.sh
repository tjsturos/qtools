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
            echo "Usage: qtools cluster-mode [--on|--off]"
            exit 1
            ;;
    esac
done

# If no flag provided, toggle current value
if [ -z "$NEW_MODE" ]; then
    CURRENT_MODE=$(yq '.service.clustering.enabled // false' $QTOOLS_CONFIG_FILE)
    if [ "$CURRENT_MODE" == "true" ]; then
        NEW_MODE="false"
    else
        NEW_MODE="true" 
    fi
fi

# Update the config file
yq -i '.service.clustering.enabled = '$NEW_MODE'' $QTOOLS_CONFIG_FILE

if [ "$NEW_MODE" == "false" ]; then
    qtools cluster-stop
    yq -i '.engine.dataWorkerMultiaddrs = []' $QUIL_CONFIG_FILE
else 
    qtools cluster-setup --master
fi


log "Cluster mode has been set to: $NEW_MODE"
