#!/bin/bash

# HELP: Transfer tokens
# PARAM: --skip-sig-check: Skip signature check (optional)
# PARAM: --to: Recipient address (required)
# PARAM: --amount: Amount to transfer (required)

source $QTOOLS_PATH/scripts/qclient/utils.sh

# Parse command line arguments
SKIP_SIG_CHECK=false
TOKEN=""
TOKEN_BALANCE=""
TO_ADDRESS=""
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
        TOKEN="$2"
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


get_to_address_from_user_input() {
    while true; do
        read -p "Enter the recipient's address (0x...) or Peer ID (Qm...): " TO_ADDRESS
        if [[ $TO_ADDRESS =~ ^0x[a-fA-F0-9]+$ ]] || [[ $TO_ADDRESS =~ ^Qm[a-zA-Z0-9]+$ ]]; then
            break
        else
            echo "Error: Invalid address format. Please enter a valid address (0x followed by alphanumeric characters) or Peer ID (Qm followed by alphanumeric characters)."
        fi
    done

    if [ -z "$TO_ADDRESS" ]; then
        echo "Error: Recipient address not found. Please try again."
        exit 1
    fi

    if [[ $TO_ADDRESS =~ ^Qm[a-zA-Z0-9]+$ ]]; then
        echo "Peer ID detected: $TO_ADDRESS"
        TO_ADDRESS=$(convert_peer_id_to_address $TO_ADDRESS)
        echo "Converted Peer ID to token address: $TO_ADDRESS"
    fi
}

convert_peer_id_to_address() {
    local PEER_ID=$1
    echo "$(qtools account-from-peer-id --peer-id $PEER_ID)"
}

# Check if TO_ADDRESS is blank
if [ -z "$TO_ADDRESS" ]; then
    get_to_address_from_user_input
fi

# Check if TOKEN is blank
if [ -z "$TOKEN" ]; then
    TOKEN=$(get_token_from_user_input $CONFIG_PATH $SKIP_SIG_CHECK)
fi

AMOUNT="$(get_token_amount $TOKEN $CONFIG_PATH $SKIP_SIG_CHECK)"

if [ -z "$AMOUNT" ]; then
    echo "Error: Token input not found. Please try again."
    exit 1
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

# Construct the command
CMD="$LINKED_QCLIENT_BINARY${SKIP_SIG_CHECK:+ --signature-check=false} token transfer $TO_ADDRESS $TOKEN --config $CONFIG_PATH"

if [[ $DRY_RUN == "false" ]]; then
    echo "Submitting transfer..."
    $CMD
    echo "Transfer submitted. This may take a while to reflect on the yours and recipient's account."
    echo "Please check the recipient's balance to confirm a successful transfer."
    echo "The token will also be removed from your coins list when processed."
    echo "Subsequent transfers of the same coin will not be processed after the first one is processed by the network.."
else
    echo "Dry run: $CMD"
fi

