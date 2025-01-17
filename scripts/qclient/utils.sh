detect_config_path() {
    local USER_CONFIG_PATH=$1

    if [[ -d "$USER_CONFIG_PATH" ]]; then
        if [[ -f "$USER_CONFIG_PATH/keys.yml" ]]; then
            if [[ -f "$USER_CONFIG_PATH/config.yml" ]]; then
                    echo "true"
            else
                echo "false"
            fi
        else
            echo "false"
        fi
    else
        echo "false"
    fi
}

get_tokens() {
    local USER_CONFIG_PATH=$1
    local SKIP_SIG_CHECK="$2"
    local CONFIG_PATH=$QUIL_NODE_PATH/.config

    if [[ $(detect_config_path $USER_CONFIG_PATH) == "true" ]]; then
        CONFIG_PATH=$USER_CONFIG_PATH
    fi
    
    local TOKENS=$($LINKED_QCLIENT_BINARY token coins --config $CONFIG_PATH ${SKIP_SIG_CHECK:+--signature-check=false} | grep "Coin 0x")
    
    if [[ -z "$TOKENS" ]]; then
        echo "Error: No tokens found"
        exit 1
    fi

    echo "$TOKENS"
}

get_config_account_address() {
    local CONFIG_PATH=$1
    local SKIP_SIG_CHECK="$2"
    if [[ $(detect_config_path $CONFIG_PATH) == "true" ]]; then
        $LINKED_QCLIENT_BINARY token balance --config $CONFIG_PATH ${SKIP_SIG_CHECK:+--signature-check=false} | grep "Account 0x" | awk '{print $NF}' | sed 's/^(Account //' | sed 's/)$//'
    else
        echo "Error: Config path not found: $CONFIG_PATH"
        exit 1
    fi
}

get_token() {
    local TOKEN=$1
    local CONFIG_PATH=${2:-$QUIL_NODE_PATH/.config}
    local SKIP_SIG_CHECK="$3"   
    local TOKEN_INFO=$(get_tokens $CONFIG_PATH ${SKIP_SIG_CHECK:+--signature-check=false} | grep $TOKEN)

    if [[ -z "$TOKEN_INFO" ]]; then
        echo "Error: Token not found: $TOKEN"
        exit 1
    fi

    echo $TOKEN_INFO
}

get_token_amount_from_info() {
    local TOKEN_INFO=$1
    echo $TOKEN_INFO | awk '{print $1}'
}

get_token_amount() {
    local TOKEN=$1
    local CONFIG_PATH=${2:-$QUIL_NODE_PATH/.config}
    local SKIP_SIG_CHECK="$3"
    local TOKEN_INFO=$(get_token $TOKEN $CONFIG_PATH $SKIP_SIG_CHECK)

    echo $TOKEN_INFO | awk '{print $1}'
}

get_token_address() {
    local TOKEN_INFO=$1
    echo $TOKEN_INFO | awk '{print $NF}' | sed 's/^(Coin //' | sed 's/)$//'
}

get_token_from_amount() {
    local AMOUNT=$1
    local CONFIG_PATH=${2:-$QUIL_NODE_PATH/.config}
    local SKIP_SIG_CHECK="$3"
    local TOKENS=$(get_tokens $CONFIG_PATH $SKIP_SIG_CHECK)
    local MATCHING_TOKENS=$(echo "$TOKENS" | awk -v amount="$AMOUNT" '$1 == amount {print}')
    
    if [[ -z "$MATCHING_TOKENS" ]]; then
        echo "Error: No tokens found with amount $AMOUNT"
        return 1
    fi

    # Get first matching token's address
    local FIRST_TOKEN=$(echo "$MATCHING_TOKENS" | head -n 1)
    local FIRST_TOKEN_ADDRESS=$(get_token_address "$FIRST_TOKEN")
    echo "$FIRST_TOKEN_ADDRESS"
    return 0
}

print_token_array() {
    local TOKEN_ARRAY=$1
    for i in "${!TOKEN_ARRAY[@]}"; do
        echo "$((i)). ${TOKEN_ARRAY[$i]}"
    done
}

get_token_from_user_input() {
    local CONFIG_PATH=$1
    local SKIP_SIG_CHECK="$2"
    local TOKENS=$(get_tokens $CONFIG_PATH $SKIP_SIG_CHECK)

    echo "$TOKENS"

    if [[ -z "$TOKENS" ]]; then
        echo "Error: No tokens found"
        exit 1
    fi

    # Create an array to store the tokens
    local TOKEN_ARRAY=()
    
    # Populate the array with tokens
    while IFS= read -r line; do
        TOKEN_ARRAY+=("$line")
    done <<< "$TOKENS"
    
    # Display the tokens with numbers
    echo "Available tokens:"
    print_token_array "${TOKEN_ARRAY[@]}"

    local SELECTED_TOKEN_INDEX=-1

    while true; do
        read -p "Select a token by number: " SELECTED_TOKEN_INDEX
        if [[ $SELECTED_TOKEN_INDEX =~ ^[0-9]+$ ]] && [[ $SELECTED_TOKEN_INDEX -gt 0 ]] && [[ $SELECTED_TOKEN_INDEX -le ${#TOKEN_ARRAY[@]} ]]; then
            echo $(($SELECTED_TOKEN_INDEX - 1))
            break
        fi
    done

    if [[ $SELECTED_TOKEN_INDEX -eq -1 ]]; then
        echo "Error: Invalid token index"
        exit 1
    fi
    
    echo $(get_token_address "${TOKEN_ARRAY[$SELECTED_TOKEN_INDEX]}")
}
