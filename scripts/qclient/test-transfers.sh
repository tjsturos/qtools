#!/bin/bash

# HELP: Test transfers by sending tokens of 0.1 QUIL to a specified address
# PARAM: --skip-sig-check: Skip signature check (optional)
# PARAM: --to: Recipient address (required)

# Parse command line arguments
SKIP_SIG_CHECK=""
TO_ADDRESS=""
AMOUNT=0.1

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --skip-sig-check)
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
        --to)
        TO_ADDRESS="$2"
        shift
        shift
        ;;
        --amount)
        AMOUNT="$2"
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

# Check if TO_ADDRESS is provided
if [ -z "$TO_ADDRESS" ]; then
    echo "Error: Recipient address (--to) is required."
    exit 1
fi

# Validate TO_ADDRESS format
if [[ ! $TO_ADDRESS =~ ^0x[a-fA-F0-9]+$ ]]; then
    echo "Error: Invalid address format. Please enter a valid Ethereum address (0x followed by 40 hexadecimal characters)."
    exit 1
fi

# Function to get total balance
get_total_balance() {
    local total_balance=$(qtools coins ${SKIP_SIG_CHECK:+--skip-sig-check} | awk '{sum += $1} END {print sum}')
    echo $total_balance
}

suitable_tokens=()
update_suitable_tokens() {
    echo "Updating suitable tokens"
    suitable_tokens=$(qtools coins ${SKIP_SIG_CHECK:+--skip-sig-check} | grep "0x" | awk -v amount="$AMOUNT" '$1 == amount {print $0}')
    # Count suitable tokens
    suitable_token_count=$(echo "$suitable_tokens" | wc -l)

    echo "Number of suitable tokens found: $suitable_token_count"
}

transfer_token() {
    local TOKEN_ID=$1
    CMD="qclient token transfer $TO_ADDRESS $TOKEN_ID ${SKIP_SIG_CHECK:+ --signature-check=false}"
    echo "Executing: $CMD"
    $CMD
}

update_suitable_tokens

# Initialize transfer count
transfer_count=0

# Main loop
while true; do
    update_suitable_tokens &

    # Iterate through all suitable tokens
    echo "$suitable_tokens" | while read -r suitable_token; do
        token_balance=$(echo $suitable_token | awk '{print $1}')
        token_id=$(echo "$suitable_token" | awk '{print $NF}' | sed 's/^(Coin //' | sed 's/)$//')

        transfer_token $token_id &

        # Increment transfer count
        ((transfer_count++))

        # Log the current number of transfers
        echo "Total transfers completed: $transfer_count"

        # Refresh the list of suitable tokens
        update_suitable_tokens &
    done
done

echo "Test transfers completed."
