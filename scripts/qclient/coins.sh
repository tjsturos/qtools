
#!/bin/bash
# HELP: Get token information
# PARAM: --skip-sig-check: Skip signature check (optional)
# PARAM: --config: Path to the config file (optional)

source $QTOOLS_PATH/scripts/qclient/utils.sh
# Parse command line arguments
SKIP_SIG_CHECK=false
CONFIG_PATH="$QUIL_NODE_PATH/.config"
SORTED=false
SORT_ORDER="asc"
HEX_ONLY=""
METADATA=false
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --hex-only)
        HEX_ONLY="true"
        shift
        ;;
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
        --sort)
        SORTED=true
        if [ "$2" == "desc" ]; then
            SORT_ORDER="desc"
        fi
        shift
        shift
        ;;
        metadata)
        METADATA=true
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
CMD="$LINKED_QCLIENT_BINARY token coins ${METADATA:+metadata} --config $CONFIG_PATH"

# Add signature check flag if needed
if [ "$SKIP_SIG_CHECK" == true ]; then
    CMD="$CMD --signature-check=false"
fi

# Execute the command and process output
if [ "$HEX_ONLY" == "true" ]; then
    TOKEN_OUTPUT=$($CMD | grep "Coin 0x" | awk '{print $NF}' | sed 's/^(Coin //' | sed 's/)$//')
else
    TOKEN_OUTPUT=$($CMD | grep "Coin 0x")
    if [ "$SORTED" == "true" ]; then
        if [ "$SORT_ORDER" == "desc" ]; then
            TOKEN_OUTPUT=$(echo "$TOKEN_OUTPUT" | sort -k1,1 -r)
        else
            TOKEN_OUTPUT=$(echo "$TOKEN_OUTPUT" | sort -k1,1)
        fi
    fi

fi

if [ ! -z "$TOKEN_OUTPUT" ]; then
    echo "$TOKEN_OUTPUT"
fi
