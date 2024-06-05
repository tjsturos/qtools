#!/bin/bash

# Function to check a peer
check_peer() {
    local peer_id=$1
    local url="https://dashboard-api.quilibrium.com/peer-test?peerId=${peer_id}"

    # Send GET request to the URL
    response=$(curl -s -w "%{http_code}" -o /tmp/peer_response.json "$url")
    http_code=$(tail -n1 <<< "$response")

    # Read the response body
    response_body=$(cat /tmp/peer_response.json)

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
    rm /tmp/peer_response.json
}

# Main script
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <peer-id>"
    exit 1
fi

peer_id="$(qtools get-peer-id)"
check_peer "$peer_id"
