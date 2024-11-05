#!/bin/bash
# HELP: Split tokens evenly by 100
# PARAM: --token: Token address to split (required)
# PARAM: --amount: Amount to split (required) 
# PARAM: --skip-sig-check: Skip signature check (optional)
# PARAM: --config: Path to the config file (optional)

source $QTOOLS_PATH/scripts/qclient/utils.sh

# Parse command line arguments
SKIP_SIG_CHECK=false
CONFIG_PATH="$QUIL_NODE_PATH/.config"
TOKEN=""
AMOUNT=""
WAIT=""
DEBUG=""

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --token)
        TOKEN="$2"
        shift
        shift
        ;;
        --all)
        TOKEN="all"
        shift
        ;;
        --amount)
        AMOUNT="$2"
        shift
        shift
        ;;
        --skip-sig-check)
        SKIP_SIG_CHECK=true
        shift
        ;;
        --wait)
        WAIT="true"
        shift
        ;;
        --debug)
        DEBUG="true"
        shift
        ;;
        --config)
        if detect_config_path "$2"; then
            CONFIG_PATH="$2"
        fi
        shift
        shift
        ;;
        *)
        # Unknown option
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
done

# Validate required parameters
if [ -z "$TOKEN" ]; then
    TOKEN=$(get_token_from_amount $AMOUNT $CONFIG_PATH $SKIP_SIG_CHECK)
    if [ $? -ne 0 ]; then
        echo "Error: No token found with amount $AMOUNT"
        exit 1
    fi
fi

if [ -z "$AMOUNT" ]; then
    echo "Error: --amount parameter is required"
    exit 1
fi

# Calculate split amount (divide by 100)
SPLIT_AMOUNT=$(echo "scale=8; $AMOUNT/100" | bc)

split_token() {
    local TOKEN=$1

    # Construct split command with 100 equal amounts
    local CMD="$LINKED_QCLIENT_BINARY token split $TOKEN"
    local TOKEN_AMOUNT_LIST=()
    for i in {1..100}; do
        TOKEN_AMOUNT_LIST+=($SPLIT_AMOUNT)
    done

    CMD="$CMD ${TOKEN_AMOUNT_LIST[@]}"

    if [ "$SKIP_SIG_CHECK" = true ]; then
        CMD="$CMD --signature-check=false"
    fi

    if [ -n "$CONFIG_PATH" ]; then
        CMD="$CMD --config $CONFIG_PATH"
    fi

    if [ -n "$DEBUG" ]; then
        echo "$CMD"
    fi
    
    $CMD > /dev/null 2>&1
}

 # Ensure AMOUNT has .0 if no decimal
if [[ ! "$AMOUNT" =~ \. ]]; then
    AMOUNT="$AMOUNT.0"
fi

GREP_AMOUNT=$(echo "$AMOUNT" | sed 's/\./\\./g')

if [ -n "$DEBUG" ]; then
    echo "GREP_AMOUNT: $GREP_AMOUNT"
fi

get_all_tokens() {
    # Escape decimal point for grep
    local ALL_TOKENS=($(get_tokens $CONFIG_PATH $SKIP_SIG_CHECK))
    local TOKENS=($(echo "$ALL_TOKENS" | grep "$GREP_AMOUNT"))
    echo "$TOKENS"
}

split_all() {
    echo "Splitting all tokens with amount $AMOUNT"
   
    # Escape decimal point for grep
    local TOKENS=($(get_all_tokens))
    echo "Found tokens:"
    for TOKEN_INFO in "${TOKENS[@]}"; do
        ADDRESS=$(get_token_address "$TOKEN_INFO")
        echo "Splitting token $ADDRESS"
        split_token $ADDRESS
    done
}

if [ "$TOKEN" = "all" ]; then
    split_all
else
    split_token $TOKEN
fi


if [ "$WAIT" = "true" ]; then
    echo "Waiting for confirmation..."
    sleep 10
    # Keep splitting while tokens with $AMOUNT exist
    while true; do
        # Get tokens with specified amount
        local REMAINING_TOKENS=($(get_all_tokens))
        
        # Exit if no more tokens with target amount
        if [ ${#REMAINING_TOKENS[@]} -eq 0 ]; then
            echo "No more tokens with amount $AMOUNT found. Exiting..."
            break
        fi

        echo "Found ${#REMAINING_TOKENS[@]} tokens with amount $AMOUNT. Splitting again..."
        split_all
        echo "Waiting 20 seconds before next check..."
        sleep 20
    done
fi

