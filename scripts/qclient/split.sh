#!/bin/bash
# HELP: Split tokens
# PARAM: --skip-sig-check: Skip signature check (optional)
# PARAM: --config: Path to the config file (optional)

source $QTOOLS_PATH/scripts/qclient/utils.sh

# Parse command line arguments
SKIP_SIG_CHECK=false
EVENLY=false
TOKEN=""
TOKEN_BALANCE=""
AMOUNT=""
NUMBER_OF_TOKENS=1
TOKEN_CREATE_ARRAY=()
DEBUG=false

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --debug)
        DEBUG=true
        shift
        ;;
        --token)
        TOKEN="$2"
        shift
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
        *)
        # Unknown option
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
done

initial_tokens_list=($(get_tokens $CONFIG_PATH $SKIP_SIG_CHECK))

get_token_from_user_input() {
    local SELECTED_TOKEN=$(get_token_from_user_input $CONFIG_PATH $SKIP_SIG_CHECK)

    if [ -z "$SELECTED_TOKEN" ]; then
        echo "Error: No token selected"
        exit 1
    fi

    TOKEN=$(echo "$SELECTED_TOKEN" | awk '{print $NF}' | sed 's/^(Coin //' | sed 's/)$//')
    TOKEN_BALANCE=$(echo "$SELECTED_TOKEN" | awk '{print $1}')
}

get_amount_from_user_input() {
    while true; do
        read -p "Enter the new token amount (max $TOKEN_BALANCE): " AMOUNT
        if [[ $AMOUNT =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            if (( $(echo "$AMOUNT <= $TOKEN_BALANCE" | bc -l) )); then
                break
            else
                echo "Error: The amount to split ($AMOUNT) is greater than the token balance ($TOKEN_BALANCE)."
            fi
        else
            echo "Error: AMOUNT must be a decimal number."
        fi
    done

}

print_token_create_array() {
    echo "Tokens that will be created:"
    for i in "${!TOKEN_CREATE_ARRAY[@]}"; do
        echo "Token $((i+1)): ${TOKEN_CREATE_ARRAY[i]} QUIL"
    done
}

get_number_of_tokens_from_user_input() {
    while true; do
        read -p "How many tokens do you wish to create? (default 1): " NUMBER_OF_TOKENS
        NUMBER_OF_TOKENS=${NUMBER_OF_TOKENS:-1}
        if [[ $NUMBER_OF_TOKENS =~ ^[0-9]+$ ]]; then
            break
        else
            echo "Error: NUMBER_OF_TOKENS must be a number."
        fi
    done

    for (( i=0; i<$NUMBER_OF_TOKENS; i++ )); do
        local TOKEN_AMOUNT
        # Calculate the current sum of TOKEN_CREATE_ARRAY
        local CURRENT_SUM=$(echo "${TOKEN_CREATE_ARRAY[@]}" | tr ' ' '+' | bc -l)
        # Calculate the amount left
        local AMOUNT_LEFT=$(echo "$TOKEN_BALANCE - $CURRENT_SUM" | bc -l)
        echo "Amount left to split: $AMOUNT_LEFT"
        while true; do
            read -p "Enter the amount for token $((i+1)) (max $AMOUNT_LEFT): " TOKEN_AMOUNT
            if [[ $TOKEN_AMOUNT =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                if (( $(echo "$TOKEN_AMOUNT <= $AMOUNT_LEFT" | bc -l) )); then
                    # Calculate the current sum of TOKEN_CREATE_ARRAY
                    local CURRENT_SUM=$(echo "${TOKEN_CREATE_ARRAY[@]}" | tr ' ' '+' | bc)
                    # Add the new TOKEN_AMOUNT
                    local NEW_SUM=$(echo "$CURRENT_SUM + $TOKEN_AMOUNT" | bc)
                    if (( $(echo "$NEW_SUM <= $TOKEN_BALANCE" | bc -l) )); then
                        TOKEN_CREATE_ARRAY+=("$TOKEN_AMOUNT")
                    else
                        echo "Error: The total sum of tokens ($NEW_SUM) would exceed the token balance ($TOKEN_BALANCE)."
                        continue
                    fi
                    break
                else
                    echo "Error: The amount ($TOKEN_AMOUNT) is greater than the amount left to split ($AMOUNT_LEFT)."
                fi
            else
                echo "Error: Amount must be a decimal number."
            fi
        done
    done
}

get_split_evenly_from_user_input() {
    while true; do
        echo "Splitting evenly will split the token into equal parts as much as possible and leave the remainder as a new token."
        echo "For example, splitting 101 tokens with amount of 2 QUIL evenly will create 50 new tokens and leave 1 token with a balance of 1 QUIL as the remainder."
        read -p "Split evenly? (y/n): " SPLIT_EVENLY
        if [[ $SPLIT_EVENLY == "y" || $SPLIT_EVENLY == "n" ]]; then
            break
        else
            echo "Error: Invalid input. Please enter 'y' or 'n'."
        fi
    done

    if [[ $SPLIT_EVENLY == "y" ]]; then
        EVENLY=true
        get_amount_from_user_input
        # Calculate the number of full tokens and the remainder
        local full_tokens=$(echo "$TOKEN_BALANCE / $AMOUNT" | bc)
        local remainder=$(echo "$TOKEN_BALANCE % $AMOUNT" | bc)

        # Add full tokens to TOKEN_CREATE_ARRAY
        for ((i=0; i<full_tokens; i++)); do
            if (( $(echo "$AMOUNT < 1" | bc -l) )); then
                AMOUNT=$(printf "%.8f" $AMOUNT)
            fi
            TOKEN_CREATE_ARRAY+=("$AMOUNT")
        done

        # Add remainder if it's greater than 0
        if (( $(echo "$remainder > 0" | bc -l) )); then
            # Ensure remainder has a leading zero if less than 1
            if (( $(echo "$remainder < 1" | bc -l) )); then
                remainder=$(printf "%.8f" $remainder)
            fi
            TOKEN_CREATE_ARRAY+=("$remainder")
        fi
    fi

    if [[ $SPLIT_EVENLY == "n" ]]; then
        get_number_of_tokens_from_user_input
    fi
}

# Check if TOKEN is blank
if [ -z "$TOKEN" ]; then
    get_token_from_user_input
    get_split_evenly_from_user_input
fi

if [ -z "$AMOUNT" ]; then
    get_amount_from_user_input
fi


echo "Using token $TOKEN with balance $TOKEN_BALANCE"


# Confirm with user before proceeding
while true; do
    echo "Token to split: $TOKEN"
    echo "Token balance: $TOKEN_BALANCE"
    print_token_create_array
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

echo "Splitting tokens... this may take a while to process."

# Function to split tokens recursively
split_tokens() {
    local token=$1
    shift
    local amounts=("$@")

    if [ ${#amounts[@]} -le 100 ]; then
        # If 100 or fewer tokens, split directly
        CMD="$LINKED_QCLIENT_BINARY${SKIP_SIG_CHECK:+ --signature-check=false} token split $token ${amounts[@]}"
        if $DEBUG; then
            echo "DEBUG: $CMD"
        fi
        $CMD
    else
        # If more than 100 tokens, split into batches of 99 + remainder
        local chunk_size=99
        local total_amount=$(echo "${amounts[@]}" | tr ' ' '+' | bc)
        local batch_amount=$(echo "scale=8; $total_amount / ${#amounts[@]}" | bc)

        while [ ${#amounts[@]} -gt 100 ]; do
            # Create an array of 99 equal parts and the remainder
            local batch_amounts=()
            for ((i=0; i<$chunk_size; i++)); do
                batch_amounts+=($batch_amount)
            done
            local remainder=$(echo "scale=8; $total_amount - ($batch_amount * $chunk_size)" | bc)
            batch_amounts+=($remainder)

            # Split into 99 equal parts + remainder
            CMD="$LINKED_QCLIENT_BINARY${SKIP_SIG_CHECK:+ --signature-check=false} token split $token ${batch_amounts[@]}"
            if $DEBUG; then
                echo "DEBUG: $CMD"
            fi
            $CMD

            # Wait for the split to complete and find the new token with the remainder amount
            echo "Waiting for split to complete..."
            local new_token=""
            while [ -z "$new_token" ]; do
                sleep 5
                new_token=$(qtools --describe "split" coins ${SKIP_SIG_CHECK:+--skip-sig-check} | awk -v amount="$remainder" '$1 == amount {print $NF}' | sed 's/^(Coin //' | sed 's/)$//')
            done

            echo "New token found: $new_token"

            # Update variables for next iteration
            token=$new_token
            total_amount=$remainder
            amounts=("${amounts[@]:$chunk_size}")
        done

        # If remaining amounts are less than or equal to 100, split directly
        if [ ${#amounts[@]} -gt 0 ]; then
            split_tokens $token "${amounts[@]}"
        fi
    fi
}

# Call the recursive function
split_tokens $TOKEN "${TOKEN_CREATE_ARRAY[@]}"

# Execute the command
$CMD

echo "Done splitting tokens. Waiting for the network to sync..."
echo "Press 'q' or any other key to quit"
while true; do
    # Allow user to quit
    read -t 1 -n 1 -p "" input
    if [[ -n $input ]]; then
        echo -e "\nQuitting..."
        exit 0
    fi
    current_tokens_list=($(qtools --describe "split" coins ${SKIP_SIG_CHECK:+--skip-sig-check}))
    if [[ "${current_tokens_list[@]}" == "${initialial_tokens_list[@]}" ]]; then
        break
    fi
    sleep 1
done
