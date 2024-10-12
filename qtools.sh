#!/bin/bash

# Determine the script's path, whether called through a symlink or directly
if [[ -L "$0" ]]; then
    # If $0 is a symlink, resolve it to the actual script path
    SCRIPT_PATH=$(readlink -f "$0")
else
    # If $0 is not a symlink, use the direct path
    SCRIPT_PATH=$(realpath "$0")
fi

# Get the directory where the script is located
export QTOOLS_PATH=$(dirname "$SCRIPT_PATH")


# Function to display usage information
usage() {
  echo "Usage: $0 [-c|--clear] <command> <params>"
  echo "Note that autocomplete should be installed.  If it doesn't work, run 'qtools add-auto-complete && source ~/.bashrc' and try again."
  echo ""
  echo "Options:"
  echo "  -c, --clear    Clear the screen before running the command"
  echo ""

  for dir in $QTOOLS_PATH/scripts/*/; do
    echo "  $(basename "$dir"):"
    for script in "$dir"*.sh; do
      script_name=$(basename "$script" .sh)
      ignore_script="$(grep '# IGNORE' $script)"
      if [ -z "$ignore_script" ]; then
        help_description=$(grep "# HELP:" "$script" | cut -d: -f2- | xargs)
        params=$(grep "# PARAM" "$script" | cut -d: -f2- | xargs -I{} echo "          {}")
        usage_lines=$(grep "# Usage:" "$script" | cut -d: -f2- | xargs -I{} echo "          {}")

        if [ -z "$help_description" ]; then
          echo "    - $script_name"
        else
          echo "    - $script_name: $help_description"
        fi

        if [ ! -z "$params" ]; then
          echo "        Params:"
          echo "$params"
        fi

        if [ ! -z "$usage_lines" ]; then
          echo "        Usage:"
          echo "$usage_lines"
        fi
      fi
    done
  done

  exit 1
}

# Check for clear flag
CLEAR_SCREEN=false
if [ "$1" == "-c" ] || [ "$1" == "--clear" ]; then
  CLEAR_SCREEN=true
  shift
fi

if [ -z "$1" ] || [ "$1" == "--help" ] || [ "$1" == '-h' ]; then
  usage
fi

# Load environment variables to be made available in all scripts
export DEBIAN_FRONTEND=noninteractive
export USER="$(whoami)"
export QUIL_PATH=$HOME/ceremonyclient
export QUIL_NODE_PATH=$QUIL_PATH/node
export QUIL_CLIENT_PATH=$QUIL_PATH/client
export QUIL_NODE_BIN=/usr/local/bin/node
export QTOOLS_BIN_PATH=/usr/local/bin/qtools
export QUIL_QCLIENT_BIN=/usr/local/bin/qclient
export SYSTEMD_SERVICE_PATH=/etc/systemd/system

# Check if SYSTEMD_SERVICE_PATH exists, if not, use /lib/systemd/system
if [ ! -d "$SYSTEMD_SERVICE_PATH" ]; then
    export SYSTEMD_SERVICE_PATH=/lib/systemd/system
    log "SYSTEMD_SERVICE_PATH not found. Using /lib/systemd/system instead."
fi


export BASHRC_FILE="$HOME/.bashrc"

# Define Go vars
export GO_BIN_DIR=/usr/local
export GOROOT=$GO_BIN_DIR/go
export GOPATH=$HOME/go
export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
export QTOOLS_CONFIG_FILE=$QTOOLS_PATH/config.yml
export QUIL_CONFIG_FILE="$QUIL_NODE_PATH/.config/config.yml"

# many util scripts require the log
if [ "$1" == "init" ]; then
  source $QTOOLS_PATH/scripts/init.sh
  exit 0
fi

export LOG_OUTPUT_FILE="$(yq '.settings.log_file' $QTOOLS_CONFIG_FILE)"
source $QTOOLS_PATH/utils/index.sh

export QUIL_SERVICE_NAME="$(yq '.service.file_name' $QTOOLS_CONFIG_FILE)"
export QUIL_SERVICE_FILE="$SYSTEMD_SERVICE_PATH/$QUIL_SERVICE_NAME.service"

# statistics service name
export STATISTICS_SERVICE_NAME="$(yq '.scheduled_tasks.statistics.service_name' $QTOOLS_CONFIG_FILE)"

export OS_ARCH="$(get_os_arch)"

# Check if the service file exists, if not, run "qtools update-service"
if [ ! -f "$QUIL_SERVICE_FILE" ] && [ "$1" != "update-service" ]; then
  log "Service file not found. Running 'qtools update-service'..."
  log "Copying service file to $SYSTEMD_SERVICE_PATH..."
  qtools update-service
fi

# Function to find the script and set SERVICE_PATH
find_script() {
  for dir in $(find "$QTOOLS_PATH/scripts" -type d); do
    for subdir in $(find "$dir" -type d); do
      for subsubdir in $(find "$subdir" -type d); do
        if [ -f "$subsubdir/$1.sh" ]; then
          export SERVICE_PATH="${subsubdir%/}"
          return 0
        fi
      done
    done
  done
  return 1
}

# Function to check if snapshots are enabled
are_snapshots_enabled() {
  local enabled=$(yq '.settings.snapshots.enabled // true' $QTOOLS_CONFIG_FILE)
  [[ "$enabled" == "true" ]]
}

NODE_BINARY=$(get_versioned_node)

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
  start)
    if are_snapshots_enabled; then
      update_snapshot
    else
      log "Snapshots are disabled. Skipping snapshot update."
    fi
    ;;
esac

# Find the script and set SERVICE_PATH
if ! find_script "$1"; then
  echo "Invalid option: $1"
  usage
fi

# Clear screen if flag is set
if [ "$CLEAR_SCREEN" == "true" ]; then
  clear
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
# List of scripts that should run as root
ROOT_SCRIPTS=("install-boost-scripts" "set_cpu_performance")

if [[ " ${ROOT_SCRIPTS[@]} " =~ " $(basename "$SCRIPT" .sh) " ]]; then
  log "Running script $SCRIPT as root"
  sudo su -c "QTOOLS_PATH=$QTOOLS_PATH $SCRIPT $*" - root
else
  source "$SCRIPT" "$@"
fi

exit 0