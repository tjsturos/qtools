
#!/bin/bash
# HELP: Get token information
# PARAM: --skip-sig-check: Skip signature check (optional)
# PARAM: --config: Path to the config file (optional)

source $QTOOLS_PATH/scripts/qclient/utils.sh
# Parse command line arguments
SKIP_SIG_CHECK=false
CONFIG_PATH="$QUIL_NODE_PATH/.config"
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --config)
        if [[ $(detect_config_path "$2") ]]; then
            CONFIG_PATH="$2"
        fi
        shift
        shift
        ;;
        --skip-sig-check)
        SKIP_SIG_CHECK=true
        shift
        ;;
        *)
        # Unknown option
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
done

# Construct the command
CMD="$LINKED_QCLIENT_BINARY token coins --config $CONFIG_PATH"

# Add signature check flag if needed
if [ "$SKIP_SIG_CHECK" == true ]; then
    CMD="$CMD --signature-check=false"
fi

# Execute the command
TOKEN_OUTPUT=$($CMD)

if [ ! -z "$TOKEN_OUTPUT" ]; then
    echo "$TOKEN_OUTPUT | grep 'Coin 0x'"
fi
