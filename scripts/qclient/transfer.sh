#!/bin/bash

# HELP: Transfer tokens
# PARAM: --skip-sig-check: Skip signature check (optional)
# PARAM: --to: Recipient address (required)
# PARAM: --amount: Amount to transfer (required)

# Parse command line arguments
SKIP_SIG_CHECK=false
TOKEN=""
TOKEN_BALANCE=""
TO_ADDRESS=""
AMOUNT=""
DRY_RUN="false"

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --dry-run)
        DRY_RUN=true
        shift
        ;;
        --skip-sig-check)
        SKIP_SIG_CHECK=true
        shift
        ;;
        --to)
        TO_ADDRESS="$2"
        shift
        shift
        ;;
        --token)
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

get_token_from_user_input() {
    # Check if there are tokens with the specified amount
    ACCOUNT_TOKENS=$(qtools get-tokens ${SKIP_SIG_CHECK:+--skip-sig-check})

    if [ -n "$ACCOUNT_TOKENS" ]; then
        echo "Available tokens:"
        IFS=$'\n' read -d '' -r -a token_array <<< "$ACCOUNT_TOKENS"
        for i in "${!token_array[@]}"; do
            echo "$((i+1)). ${token_array[i]}"
        done
        # Prompt user if they want to use one of these tokens
        echo "Which token would you like to use? Enter the token ID or 'q' to exit:"
        select TOKEN in $(echo "$ACCOUNT_TOKENS" | awk '{print $NF}' | sed 's/^(Coin //' | sed 's/)$//') "q"; do
            case $TOKEN in
                q)
                    echo "Exiting..."
                    exit 0
                    ;;
                *)
                    if [ -n "$TOKEN" ]; then
                        TOKEN_BALANCE=$(echo "$ACCOUNT_TOKENS" | awk -v token="$TOKEN" '$NF ~ token {print $1}')
                        echo "Selected token: $TOKEN with balance: $TOKEN_BALANCE QUIL"
                        break
                    else
                        echo "Invalid selection. Please try again or enter 'q' to exit."
                    fi
                    ;;
            esac
        done
    fi
}

get_to_address_from_user_input() {
    while true; do
        read -p "Enter the recipient's address (0x...) or Peer ID (Qm...): " TO_ADDRESS
        if [[ $TO_ADDRESS =~ ^0x[a-fA-F0-9]{40}$ ]] || [[ $TO_ADDRESS =~ ^Qm[a-zA-Z0-9]+$ ]]; then
            break
        else
            echo "Error: Invalid address format. Please enter a valid address (0x followed by 40 hexadecimal characters) or Peer ID (Qm followed by alphanumeric characters)."
        fi
    done

    if [ -z "$TO_ADDRESS" ]; then
        echo "Error: Recipient address not found. Please try again."
        exit 1
    fi

    if [[ $TO_ADDRESS =~ ^Qm[a-zA-Z0-9]+$ ]]; then
        echo "Peer ID detected: $TO_ADDRESS"
        TO_ADDRESS=$(qtools account-from-peer-id --peer-id $TO_ADDRESS)
        echo "Converted Peer ID to token address: $TO_ADDRESS"
    fi
}

get_token_amount() {
    local TOKEN_NAME=$1
    echo "$(qtools get-tokens ${SKIP_SIG_CHECK:+--skip-sig-check} | awk -v token="$TOKEN_NAME" '$NF ~ token {print $1}')"
}

# Check if TOKEN is blank
if [ -z "$TOKEN" ]; then
    get_token_from_user_input
fi

AMOUNT="$(get_token_amount $TOKEN)"
echo "Found token: $TOKEN with balance: $AMOUNT QUIL"
if [ -z "$AMOUNT" ]; then
    echo "Error: Token input not found. Please try again."
    exit 1
fi

# Check if TO_ADDRESS is blank
if [ -z "$TO_ADDRESS" ]; then
    get_to_address_from_user_input
fi

echo "Transferring $AMOUNT QUIL from token $TOKEN to address $TO_ADDRESS"

# Confirm with user before proceeding
while true; do
    read -p "Is this correct? Do you want to proceed? (y/n): " CONFIRM
    if [[ $CONFIRM == "y" || $CONFIRM == "n" ]]; then
        break
    else
        echo "Error: Invalid input. Please enter 'y' or 'n'."
    fi
done

if [[ $CONFIRM == "n" ]]; then
    echo "Operation cancelled by user."
    exit 0
fi

echo "Transferring tokens... this may take a while to process."

# Construct the command
CMD="$LINKED_QCLIENT_BINARY${SKIP_SIG_CHECK:+ --signature-check=false} token transfer $TO_ADDRESS $TOKEN"

if [[ $DRY_RUN == "false" ]]; then
    $CMD
else
    echo "Dry run: $CMD"
fi

echo "Transfer complete. Please check the recipient's balance to confirm the transaction."
