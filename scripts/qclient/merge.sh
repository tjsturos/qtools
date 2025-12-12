#!/bin/bash

# HELP: Merge tokens in batches of 100
# PARAM: --skip-sig-check: Skip signature check (optional)

# Parse command line arguments
SKIP_SIG_CHECK=""
PUBLIC_RPC=""
COINS=()
MERGE_ALL=false
CONFIG="$QUIL_NODE_PATH/.config"
BATCH_SIZE=100
BATCH=""
DEBUG=""
cd $QUIL_NODE_PATH

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --debug|-d)
        DEBUG="true"
        shift
        ;;
        --batch|-b)
        BATCH="true"
        BATCH_SIZE="$2"
        shift 2
        ;;
        --config|-c)
        if [ -d "$2" ]; then
            CONFIG="$2"
        else
            echo "Error: $2 is not a directory"
            exit 1
        fi
        shift 2
        ;;
        --skip-sig-check|-s)
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
        COINS=($(qtools coins ${SKIP_SIG_CHECK:+--skip-sig-check} --hex-only --config $CONFIG))
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
merge_all_by_batch() {
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
            if [ "$DEBUG" == "true" ]; then
                echo "Executing: $CMD"
            fi
            $CMD

            # Wait briefly between batches
            sleep 2
        fi

        start=$end
    done
}

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

if [ "$BATCH" == "true" ]; then
    merge_all_by_batch "${COINS[@]}"
else
    merge_all "${COINS[@]}"
fi

echo "Merge operations submitted. Please wait for network processing..."
