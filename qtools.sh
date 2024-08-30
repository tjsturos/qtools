#!/bin/bash

# Resolve symlinks and get the real path of the script
SCRIPT_PATH=$(realpath "$0")

# Get the directory where the script is actually located
export QTOOLS_PATH=$(dirname "$SCRIPT_PATH")

# Function to display usage information
usage() {
  echo "Usage: $0 <command> <params>"
  echo "Note that autocomplete should be installed. If it doesn't work, run 'qtools add-auto-complete && source ~/.zshrc' and try again."
  echo ""
  echo "Options:"

  for dir in "$QTOOLS_PATH"/scripts/*/; do
    echo "  $(basename "$dir"):"
    for script in "$dir"*.sh; do
      script_name=$(basename "$script" .sh)
      ignore_script=$(grep '# IGNORE' "$script")
      if [[ -z "$ignore_script" ]]; then
        help_description=$(grep "# HELP:" "$script" | cut -d: -f2- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        params=$(grep "# PARAM" "$script" | cut -d: -f2- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        usage_lines=$(grep "# Usage:" "$script" | cut -d: -f2- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        
        if [[ -z "$help_description" ]]; then
          echo "    - $script_name"
        else
          echo "    - $script_name: $help_description"
        fi
        
        if [[ -n "$params" ]]; then
          echo "        Params:"
          echo "$params" | sed 's/^/          /'
        fi
        
        if [[ -n "$usage_lines" ]]; then
          echo "        Usage:"
          echo "$usage_lines" | sed 's/^/          /'
        fi
      fi
    done
  done

  exit 1
}

if [[ -z "$1" ]] || [[ "$1" == "--help" ]] || [[ "$1" == '-h' ]]; then
  usage
fi

# Load environment variables to be made available in all scripts
export USER="$(whoami)"
export QUIL_PATH=$HOME/ceremonyclient
export QUIL_NODE_PATH=$QUIL_PATH/node
export QUIL_CLIENT_PATH=$QUIL_PATH/client
export QUIL_GO_NODE_BIN=$HOME/go/bin/node
export QTOOLS_BIN_PATH=/usr/local/bin/qtools
export QUIL_QCLIENT_BIN=/usr/local/bin/qclient

export BASHRC_FILE="$HOME/.zshrc"
export GO_BIN_DIR=/usr/local/opt
export LAUNCHD_PLIST_DIR="$HOME/Library/LaunchAgents"

export GOROOT=$GO_BIN_DIR/go
export GOPATH=$HOME/go
export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
export QTOOLS_CONFIG_FILE=$QTOOLS_PATH/config.yml

# many util scripts require the log
if [[ "$1" == "init-qtools" ]]; then
  source "$QTOOLS_PATH/scripts/init-qtools.sh"
  exit 0
fi

export LOG_OUTPUT_FILE="$(yq '.settings.log_file' "$QTOOLS_CONFIG_FILE")"
source "$QTOOLS_PATH/utils.sh"

export QUIL_SERVICE_NAME="$(yq '.service.file_name' "$QTOOLS_CONFIG_FILE")"
export QUIL_SERVICE_FILE="$LAUNCHD_PLIST_DIR/com.$USER.$QUIL_SERVICE_NAME.plist"
export OS_ARCH="$(get_os_arch)"

# Function to find the script and set SERVICE_PATH
find_script() {
  for dir in "$QTOOLS_PATH"/scripts/*/; do
    if [[ -f "$dir/$1.sh" ]]; then
      export SERVICE_PATH="${dir%/}"
      return 0
    fi
  done
  return 1
}

# Set environment variables based on the option
case "$1" in
  peer-id|unclaimed-balance)
    cd "$QUIL_NODE_PATH"
    export QUIL_BIN=$(get_versioned_node)
    ;;
  get-node-count|get-node-info|get-peer-info|get-token-info|get-node-version|get-peer-id|get-frame-count)
    if ! command_exists grpcurl; then
      log "Command 'grpcurl' doesn't exist, proceeding to install."
      qtools install-grpc
    fi
    ;;
esac

# Find the script and set SERVICE_PATH
if ! find_script "$1"; then
  echo "Invalid option: $1"
  usage
fi

# Construct the full filename
SCRIPT="$SERVICE_PATH/$1.sh"

# Check if the file exists
if [[ ! -f "$SCRIPT" ]]; then
  echo "Error: File '$SCRIPT' does not exist."
  exit 1
fi

# remove the script name
shift 1

# Source the provided script
source "$SCRIPT" "$@"

exit 0