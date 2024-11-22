#!/bin/bash
# HELP: Get account address from config
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

# Get account address using utility function
ACCOUNT=$(get_config_account_address "$CONFIG_PATH" ${SKIP_SIG_CHECK:+--signature-check=false})

if [ ! -z "$ACCOUNT" ]; then
    echo "$ACCOUNT"
fi
