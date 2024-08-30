#!/bin/bash
# HELP: Checks the Quilibrium Dashboard to see if this peer can be seen.

# Function to check a peer
check_peer() {
    local peer_id=$1
    local url="https://dashboard-api.quilibrium.com/peer-test?peerId=${peer_id}"

    # Create a temporary file using mktemp
    local temp_file=$(mktemp)

    # Send GET request to the URL
    response=$(curl -s -w "%{http_code}" -o "$temp_file" "$url")
    http_code=$(tail -n1 <<< "$response")

    # Read the response body
    response_body=$(cat "$temp_file")

    # Check the HTTP status code
    if [[ "$http_code" -eq 200 ]]; then
        echo "Response: $response_body"
        if [[ "$response_body" == *'"success":true'* ]]; then
            echo "Peer check successful"
        else
            echo "Peer check failed: $response_body"
        fi
    else
        echo "Failed to reach the server. HTTP Status code: $http_code"
        echo "Error response: $response_body"
    fi

    # Clean up
    rm "$temp_file"
}

peer_id="$(qtools peer-id)"
check_peer "$peer_id"
