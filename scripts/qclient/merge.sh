#!/bin/bash

# HELP: Merge tokens in batches of 100
# PARAM: --skip-sig-check: Skip signature check (optional)

# Parse command line arguments
SKIP_SIG_CHECK=""
PUBLIC_RPC=""
COINS=()
MERGE_ALL=false
CONFIG="$QUIL_NODE_PATH/.config"

cd $QUIL_NODE_PATH

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --config)
        if [ -d "$2" ]; then
            CONFIG="$2"
        else
            echo "Error: $2 is not a directory"
            exit 1
        fi
        CONFIG="$2"
        shift 2
        ;;
        --skip-sig-check)
        SKIP_SIG_CHECK=true
        shift
        ;;
        --public-rpc|-p)
        PUBLIC_RPC="true"
        shift
        ;;
        all)
        MERGE_ALL=true
        shift
        ;;
        0x*)
        # Add coin ID to array if it starts with 0x
        COINS+=("$1")
        shift
        ;;
        *)
        # Unknown option
        echo "Unknown option: $1"
        echo "Usage: qtools merge [--skip-sig-check] [--public-rpc|-p] <coin_ids...>|all"
        exit 1
        ;;
    esac
done

# If no coins specified, error out unless "all" flag is used
if [ ${#COINS[@]} -eq 0 ]; then
    if [ "$MERGE_ALL" == "true" ]; then
        COINS=($(qtools coins ${SKIP_SIG_CHECK:+--skip-sig-check} --hex-only))
    else
        echo "Error: No coins specified. Use 'all' flag to merge all coins or specify coin IDs."
        exit 1
    fi
fi

if [ ${#COINS[@]} -lt 2 ]; then
    echo "Not enough coins to merge. Need at least 2 coins."
    exit 1
fi

echo "Found ${#COINS[@]} coins to merge"

# Function to merge coins in batches
merge_batch() {
    local coins=("$@")
    local batch_size=100
    local start=0
    
    while [ $start -lt ${#coins[@]} ]; do
        # Calculate end index for current batch
        local end=$((start + batch_size))
        if [ $end -gt ${#coins[@]} ]; then
            end=${#coins[@]}
        fi
        
        # Extract batch of coins
        local batch=("${coins[@]:start:batch_size}")
        
        if [ ${#batch[@]} -gt 1 ]; then
            echo "Merging batch of ${#batch[@]} coins..."
            CMD="qclient token merge ${batch[@]}${SKIP_SIG_CHECK:+ --signature-check=false}${PUBLIC_RPC:+ --public-rpc} --config $CONFIG"
            echo "Executing: $CMD"
            $CMD
            
            # Wait briefly between batches
            sleep 2
        fi
        
        start=$end
    done
}

# Start merging
merge_batch "${COINS[@]}"

echo "Merge operations submitted. Please wait for network processing..."
