#!/bin/bash
# HELP: Transfers all tokens from a carousel peer config to a specified deposit account
# PARAM: --deposit-account|-d: Deposit account address (required, hex format)
# Usage: qtools transfer-all-tokens --deposit-account 0x...

DEPOSIT_ACCOUNT=""
PIDS=()
RATE_LIMIT_DELAY=0.2  # 200ms delay between requests (5 req/s)

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --deposit-account|-d)
            DEPOSIT_ACCOUNT="$2"
            shift 2
            ;;
        *)
            echo "Invalid argument: $1"
            exit 1
            ;;
    esac
done

# Validate deposit account
if [ -z "$DEPOSIT_ACCOUNT" ]; then
    echo "Error: Deposit account is required (--deposit-account|-d)"
    exit 1
fi

if [[ ! "$DEPOSIT_ACCOUNT" =~ ^0x[0-9a-fA-F]+$ ]]; then
    echo "Error: Deposit account must be in hex format (0x...)"
    exit 1
fi

# Add rate limiting function
rate_limit() {
    sleep $RATE_LIMIT_DELAY
}

# Check if config needs migration
if ! yq eval '.scheduled_tasks.config_carousel' $QTOOLS_CONFIG_FILE >/dev/null 2>&1; then
    echo "Config needs migration. Running migration..."
    qtools migrate-qtools-config
fi

# Add logging function
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    logger -t "qtools-transfer-all-tokens" "$1"
}

# Change to the node directory
cd $QUIL_NODE_PATH || exit 1

# Get the peer list from config carousel
PEER_LIST=$(yq eval '.scheduled_tasks.config_carousel.peer_list[]' $QTOOLS_CONFIG_FILE)

if [ -z "$PEER_LIST" ]; then
    log_message "Error: No peer IDs configured in scheduled_tasks.config_carousel.peer_list"
    exit 1
fi

# Process each peer in the list
while IFS= read -r PEER_ID; do
    (
        log_message "Processing peer: $PEER_ID"
        
        # Get all tokens for this peer's config
        rate_limit
        TOKENS=$($LINKED_QCLIENT_BINARY token coins --config=$PEER_ID --public-rpc)
        
        if [ -z "$TOKENS" ]; then
            log_message "No tokens found for peer $PEER_ID, skipping..."
            exit 0
        fi
        
        # Count tokens that contain "Coin"
        TOKEN_COUNT=$(echo "$TOKENS" | grep -c "Coin")
        
        if [ "$TOKEN_COUNT" -gt 1 ]; then
            log_message "Found $TOKEN_COUNT tokens. Running token merge..."
            rate_limit
            $LINKED_QCLIENT_BINARY token merge all --config=$PEER_ID
            
            # Wait for consolidation to complete
            while true; do
                sleep 20
                rate_limit
                CURRENT_TOKENS=$($LINKED_QCLIENT_BINARY token coins --config=$PEER_ID --public-rpc)
                CURRENT_COUNT=$(echo "$CURRENT_TOKENS" | grep -c "Coin")
                
                log_message "Current token count: $CURRENT_COUNT"
                if [ "$CURRENT_COUNT" -lt "$TOKEN_COUNT" ]; then
                    log_message "Token consolidation completed. Proceeding with transfers..."
                    TOKENS=$CURRENT_TOKENS
                    break
                fi
                log_message "Waiting for token consolidation..."
            done
        fi
        
        # Process each token
        while IFS= read -r TOKEN_INFO; do
            if [ -n "$TOKEN_INFO" ] && [[ "$TOKEN_INFO" == *"Coin"* ]]; then
                # Extract token address using the utility function logic
                TOKEN_ADDRESS=$(echo "$TOKEN_INFO" | awk '{print $NF}' | sed 's/^(Coin //' | sed 's/)$//')
                
                log_message "Starting transfer of token $TOKEN_ADDRESS to $DEPOSIT_ACCOUNT"
                rate_limit
                if $LINKED_QCLIENT_BINARY token transfer $DEPOSIT_ACCOUNT $TOKEN_ADDRESS --config=$PEER_ID --public-rpc; then
                    log_message "Successfully transferred token $TOKEN_ADDRESS"
                else
                    log_message "Failed to transfer token $TOKEN_ADDRESS"
                fi
            fi
        done <<< "$TOKENS"
        
        log_message "Completed all transfers for peer $PEER_ID"
    ) &
    
    # Store the background process ID
    PIDS+=($!)
    
    # Add delay between launching peer processes to stagger the initial requests
    sleep 0.5
done <<< "$PEER_LIST"

# Wait for all peer processes to complete
for PID in "${PIDS[@]}"; do
    wait $PID
done

log_message "All token transfers completed"
