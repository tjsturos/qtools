#!/bin/bash

# Get the directory where the script is located
QTOOLS_PATH=$(dirname "$SCRIPT_PATH")

# Function to display usage information
usage() {
  echo "Usage: $0 <command> <params>"
  echo "Note that autocomplete should be installed.  If it doesn't work, run 'qtools add-auto-complete' and try again."
  echo ""
  echo "Options:"

  for dir in $QTOOLS_PATH/scripts/*/; do
    echo "  $(basename "$dir"):"
    for script in "$dir"*.sh; do
      script_name=$(basename "$script" .sh)
      ignore_script="$(grep '# IGNORE' $script)"
      if [ -z "$ignore_script" ]; then
        help_description=$(grep "# HELP:" "$script" | cut -d: -f2- | xargs)
        params=$(grep "# PARAM" "$script" | cut -d: -f2- | xargs -I{} echo "        - {}")
        usage_lines=$(grep "# Usage:" "$script" | cut -d: -f2- | xargs -I{} echo "        - {}")
        
        if [ -z "$help_description" ]; then
          echo "    - $script_name"
        else
          echo "    - $script_name: $help_description"
        fi
        
        if [ ! -z "$params" ]; then
          echo "      Params:"
          echo "$params"
        fi
        
        if [ ! -z "$usage_lines" ]; then
          echo "      Usage:"
          echo "$usage_lines"
        fi
      fi
    done
  done

  exit 1
}


if [ -z "$1" ]; then
  usage
fi

# Load environment variables to be made available in all scripts
export DEBIAN_FRONTEND=noninteractive
export QUIL_PATH=$HOME/ceremonyclient
export QUIL_NODE_PATH=$QUIL_PATH/node
export QUIL_CLIENT_PATH=$QUIL_PATH/client
export QUIL_GO_NODE_BIN=$HOME/go/bin/node
export QTOOLS_BIN_PATH=/usr/local/bin/qtools
export QUIL_QCLIENT_BIN=/usr/local/bin/qclient
export SYSTEMD_SERVICE_PATH=/lib/systemd/system

export BASHRC_FILE="$HOME/.bashrc"

# Define Go vars
export GO_BIN_DIR=/usr/local
export GOROOT=$GO_BIN_DIR/go
export GOPATH=$HOME/go
export PATH=$GOPATH/bin:$GOROOT/bin:$PATH

# Determine the script's path, whether called through a symlink or directly
if [[ -L "$0" ]]; then
    # If $0 is a symlink, resolve it to the actual script path
    SCRIPT_PATH=$(readlink -f "$0")
else
    # If $0 is not a symlink, use the direct path
    SCRIPT_PATH=$(realpath "$0")
fi

export QTOOLS_CONFIG_FILE=$QTOOLS_PATH/config.yml

if [ ! -f "$QTOOLS_CONFIG_FILE" ]; then
  cp $QTOOLS_PATH/config.sample.yml $QTOOLS_PATH/config.yml
  echo "Copied the default config file (config.sample.yml) to make the initial config.yml file."  
  echo "To edit, use 'qtools edit-qtools-config' command"
fi

if ! command -v "yq" >/dev/null 2>&1; then
  source $QTOOLS_PATH/scripts/install/install-yq.sh
  if ! command -v "yq" >/dev/null 2>&1; then
    echo "Could not install command 'yq'.  Please try again or install manually."
    exit 1
  fi
fi

# many util scripts require the log
export LOG_OUTPUT_FILE="$(yq '.settings.log_file' $QTOOLS_CONFIG_FILE)"
source $QTOOLS_PATH/utils.sh

install_package colordiff colordiff
install_package jq jq
install_package base58 base58

# Remaining scripts need existance of the QTOOLS_BIN_PATH binary
if [ ! -L "$QTOOLS_BIN_PATH" ]; then
  # Attempt to install it.
  log "$QTOOLS_BIN_PATH not found.  Attempting to install."
  source $QTOOLS_PATH/scripts/install/create-qtools-symlink.sh

  if [ ! -L "$QTOOLS_BIN_PATH" ]; then
    log "Attempted to install $QTOOLS_BIN_PATH, but failed. This is required to proceed. Try \"sudo ln -s $QTOOLS_PATH/qtools.sh /usr/local/bin/qtools\" manually."
    exit 1
  else
    log "$QTOOLS_BIN_PATH installed successfully."
    qtools add-auto-complete
  fi
fi

export QUIL_SERVICE_NAME="$(yq '.service.file_name' $QTOOLS_CONFIG_FILE)"
export QUIL_SERVICE_FILE="$SYSTEMD_SERVICE_PATH/$QUIL_SERVICE_NAME@.service"
export OS_ARCH="$(get_os_arch)"

# Function to find the script and set SERVICE_PATH
find_script() {
  for dir in $QTOOLS_PATH/scripts/*/; do
    if [ -f "$dir/$1.sh" ]; then
      export SERVICE_PATH="$dir"
      return 0
    fi
  done
  return 1
}

# Set environment variables based on the option
case "$1" in
  peer-id|unclaimed-balance)
    cd $QUIL_NODE_PATH
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
if [ ! -f "$SCRIPT" ]; then
  echo "Error: File '$SCRIPT' does not exist."
  exit 1
fi

# remove the script name
shift 1

# Source the provided script
source "$SCRIPT" "$@"