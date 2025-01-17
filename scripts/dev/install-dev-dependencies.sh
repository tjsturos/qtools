#!/bin/bash

QUIL_DEV_REPO_URL=$(yq '.dev.default_repo_url // "https://github.com/QuilibriumNetwork/ceremonyclient.git"' $QTOOLS_CONFIG_FILE)
QUIL_DEV_REPO_BRANCH=$(yq '.dev.default_repo_branch // "develop"' $QTOOLS_CONFIG_FILE)
QUIL_DEV_REPO_PATH=$(eval echo $(yq '.dev.default_repo_path // "$HOME/quil-dev"' $QTOOLS_CONFIG_FILE))

if [ ! -d "$QUIL_DEV_REPO_PATH" ]; then
  git clone $QUIL_DEV_REPO_URL $QUIL_DEV_REPO_PATH
  cd $QUIL_DEV_REPO_PATH
  git checkout $QUIL_DEV_REPO_BRANCH
fi

# Function to install dependencies
install_dependencies() {
    # Detect OS and architecture
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)

    # Install dependencies
    if [[ "$OS" == "linux" ]]; then
        sudo apt-get update -qq
        sudo apt-get install -y -qq curl build-essential libgmp-dev wget cpulimit
    elif [[ "$OS" == "darwin" ]]; then
        if ! command -v brew &> /dev/null; then
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" > /dev/null
        fi
        brew install -q curl gmp wget cpulimit
    else
        echo "Unsupported operating system: $OS"
        exit 1
    fi
}

# Function to install Rust and Go
install_rust_and_go() {
    # Check if Rust is installed
    if ! command -v rustc &> /dev/null; then
        echo "Rust not found. Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source $HOME/.cargo/env
        echo 'export PATH=$PATH:$HOME/.cargo/env' >> $HOME/.bashrc
        echo 'export PATH=$PATH:$HOME/.cargo/env' >> $HOME/.zshrc
    else
        echo "Rust is already installed."
    fi

    # Install uniffi-bindgen-go 
    if ! command -v uniffi-bindgen-go &> /dev/null; then
        echo "uniffi-bindgen-go not found. Installing..."
        cargo install uniffi-bindgen-go --git https://github.com/NordSecurity/uniffi-bindgen-go --tag v0.2.1+v0.25.0
    else
        echo "uniffi-bindgen-go is already installed."
    fi

    # Check if Go is installed
    if ! command -v go &> /dev/null; then
        qtools install-go 1.22.5
        # Install grpcurl for RPC testing
        go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest
    else
        echo "Go is already installed."
    fi
}

generate_rust_bindings() {
    echo "Generating Rust bindings..."
    cd $QUIL_DEV_REPO_PATH/vdf
    ./generate.sh

    cd $QUIL_DEV_REPO_PATH/bls48581
    ./generate.sh
}

# Run the installation functions
install_dependencies
install_rust_and_go
source ~/.bashrc
generate_rust_bindings

echo "Dev dependencies installed successfully."