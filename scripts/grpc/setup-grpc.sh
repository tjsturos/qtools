#!/bin/bash

# HELP: This script installs grpcurl, jq, and base58 if they are not already installed, then retrieves peer information from a Quilibrium node.

# Welcome
echo "✨ This script will retrieve your Qnode peer manifest ✨"
echo "Made with 🔥 by LaMat"
echo "Processing... ⏳"
echo ""
sleep 7  # Add a 7-second delay

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install Homebrew if not installed
if ! command_exists brew; then
    echo "📦 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install gRPCurl if not installed
echo "📦 Installing gRPCurl..."
sleep 1  # Add a 1-second delay

if command_exists grpcurl; then
    echo "✅ gRPCurl is already installed."
else
    # Install gRPCurl using Homebrew
    if brew install grpcurl; then
        echo "✅ gRPCurl installed successfully via Homebrew."
    else
        echo "❌ Failed to install gRPCurl! Please install it manually."
        exit 1
    fi
fi

# Install jq if not installed
if ! command_exists jq; then
    echo "📦 Installing jq..."
    brew install jq
fi

# Install base58 if not installed
if ! command_exists base58; then
    echo "📦 Installing base58..."
    brew install base58
fi

# Command to retrieve peer information
get_peer_info_command="peer_id_base64=\$(grpcurl -plaintext localhost:8337 quilibrium.node.node.pb.NodeService.GetNodeInfo | jq -r .peerId | base58 -d | base64) && grpcurl -plaintext localhost:8337 quilibrium.node.node.pb.NodeService.GetPeerManifests | grep -A 15 -B 1 \"\$peer_id_base64\""

# Execute the command
echo "🚀 Retrieving peer information..."
eval $get_peer_info_command

# Check for errors
if [ $? -ne 0 ]; then
    echo "❌ Error: Failed to retrieve peer information. Please make sure your Quilibrium node is running and accessible."
    exit 1
fi

echo ""
echo ""
echo "🎉 Peer information retrieved successfully!"
