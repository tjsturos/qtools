#!/bin/bash

# Get transfer address from config
TRANSFER_ADDRESS=$(yq eval '.settings.transfer_address' $QTOOLS_CONFIG_FILE)

# Parse command line arguments
DRY_RUN=false
TRANSFER_TO=""
SKIP_SIG_CHECK=false
PUBLIC_RPC=false
CONFIG="$QUIL_NODE_PATH/.config"
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --dry-run)
        DRY_RUN=true
        shift
        ;;
        --transfer-to|--to)
        TRANSFER_TO="$2"
        shift
        shift
        ;;
        --skip-sig-check|-s)
        SKIP_SIG_CHECK=true
        shift
        ;;
        --signature-check=*)
        VALUE="${1#*=}"
        if [ "$VALUE" == "false" ]; then
            SKIP_SIG_CHECK=true
        fi
        shift
        ;;
        --public-rpc|-p)
        PUBLIC_RPC=true
        shift
        ;;
        --config|-c)
        CONFIG="$2"
        shift
        ;;
        *)
        # Unknown option
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
done

# Override transfer address if provided via CLI
if [ -n "$TRANSFER_TO" ]; then
    TRANSFER_ADDRESS="$TRANSFER_TO"
fi

if [ -z "$TRANSFER_ADDRESS" ]; then
    echo "Error: Transfer address not configured in qtools config or provided via CLI (--transfer-to or --to)"
    exit 1
fi

# Get all tokens and sum
TOKENS=$(qtools coins --config $CONFIG ${SKIP_SIG_CHECK:+ --signature-check=false}${PUBLIC_RPC:+ --public-rpc})
TOTAL=0

# Calculate total across all tokens
for token in $TOKENS; do
    amount=$(echo $token | cut -d',' -f2)
    TOTAL=$(echo "$TOTAL + $amount" | bc)
done

echo "Total amount across all tokens: $TOTAL"

merge_all() {
    local coins=("$@")

    if [ ${#coins[@]} -gt 1 ]; then
        echo "Merging ${#coins[@]} coins..."
        CMD="qclient token merge ${coins[@]}${SKIP_SIG_CHECK:+ --signature-check=false}${PUBLIC_RPC:+ --public-rpc} --config $CONFIG"
        if [ "$DEBUG" == "true" ]; then
            echo "Executing: $CMD"
        fi
        $CMD
    fi
}

merge_all "${TOKENS[@]}"

echo "Waiting for consolidated token, this may take a few minutes..."
# Wait for consolidated token
while true; do
    TOKENS=$(qtools coins --config $CONFIG ${SKIP_SIG_CHECK:+ --signature-check=false}${PUBLIC_RPC:+ --public-rpc})
    for token in $TOKENS; do
        amount=$(echo $token | cut -d',' -f2)
        token_id=$(echo $token | cut -d',' -f1)

        # Check if this token has the total amount
        if (( $(echo "$amount == $TOTAL" | bc -l) )); then
            echo "Found consolidated token: $token_id with amount $amount"
            if [ "$DRY_RUN" == "false" ]; then
                qtools transfer --to "$TRANSFER_ADDRESS" --token "$token_id" --no-confirm
            else
                echo "Dry run: Would transfer $amount QUIL to $TRANSFER_ADDRESS"
            fi
            exit 0
        fi
    done
    echo "Waiting for consolidated token..."
    sleep 10
done
