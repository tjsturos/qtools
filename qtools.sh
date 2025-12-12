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
  echo "Usage: $0 [-c|--clear] [--describe <label>] <command> <params>"
  echo "Note that autocomplete should be installed.  If it doesn't work, run 'qtools add-auto-complete && source ~/.bashrc' and try again."
  echo ""
  echo "Options:"
  echo "  -c, --clear           Clear the screen before running the command"
  echo "  --describe <label>    Label command origin in logs (e.g., 'crontab', 'complete-install')"
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

# Check for describe flag (for tracking command origin)
# Preserve existing QTOOLS_DESCRIBE from parent if not overridden
if [ "$1" == "--describe" ]; then
  if [ -z "$2" ]; then
    echo "Error: --describe requires a value"
    exit 1
  fi
  QTOOLS_DESCRIBE="$2"
  export QTOOLS_DESCRIBE
  shift 2
fi
# If --describe not provided, QTOOLS_DESCRIBE will be inherited from parent or remain unset
# After we determine the command name, we'll auto-set QTOOLS_DESCRIBE if not already set

if [ -z "$1" ] || [ "$1" == "--help" ] || [ "$1" == '-h' ]; then
  usage
fi

# Load environment variables to be made available in all scripts
export DEBIAN_FRONTEND=noninteractive
export USER="$(whoami)"
export QTOOLS_CONFIG_FILE=$QTOOLS_PATH/config.yml

# Determine the base path for Quilibrium files based on service user configuration
# Check if config file exists and if quilibrium user is configured
QUIL_BASE_PATH="$HOME/ceremonyclient"
if [ -f "$QTOOLS_CONFIG_FILE" ] && command -v yq >/dev/null 2>&1; then
    SERVICE_USER=$(yq '.service.default_user // "quilibrium"' $QTOOLS_CONFIG_FILE 2>/dev/null || echo "quilibrium")
    if [ "$SERVICE_USER" == "quilibrium" ]; then
        # Use quilibrium user's home directory
        QUIL_BASE_PATH="/home/quilibrium/ceremonyclient"
        # Check if quilibrium_node_path is configured
        CONFIGURED_NODE_PATH=$(yq '.service.quilibrium_node_path // ""' $QTOOLS_CONFIG_FILE 2>/dev/null)
        if [ -n "$CONFIGURED_NODE_PATH" ] && [ "$CONFIGURED_NODE_PATH" != "null" ] && [ "$CONFIGURED_NODE_PATH" != "" ]; then
            # Replace $HOME with /home/quilibrium for quilibrium user
            CONFIGURED_NODE_PATH=$(echo "$CONFIGURED_NODE_PATH" | sed "s|\$HOME|/home/quilibrium|g")
            # Expand any remaining variables
            QUIL_NODE_PATH_FROM_CONFIG=$(eval echo "$CONFIGURED_NODE_PATH" 2>/dev/null || echo "")
            if [ -n "$QUIL_NODE_PATH_FROM_CONFIG" ] && [ -d "$(dirname "$QUIL_NODE_PATH_FROM_CONFIG" 2>/dev/null)" ]; then
                QUIL_BASE_PATH=$(dirname "$QUIL_NODE_PATH_FROM_CONFIG" 2>/dev/null | sed 's|/node$||' || echo "$QUIL_BASE_PATH")
            fi
        fi
    fi
fi

export QUIL_PATH=$QUIL_BASE_PATH
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
export QUIL_KEYS_FILE="$QUIL_NODE_PATH/.config/keys.yml"
export QUIL_CONFIG_FILE="$QUIL_NODE_PATH/.config/config.yml"

# many util scripts require the log
if [ "$1" == "init" ] || [ ! -f "$QTOOLS_PATH/INIT_COMPLETE" ]; then
  source $QTOOLS_PATH/scripts/init.sh
  exit 0
fi

export IS_TESTNET=$(yq '.service.testnet' $QTOOLS_CONFIG_FILE 2>/dev/null || echo "false")

if [ "$IS_TESTNET" == "true" ]; then
  export QUIL_NODE_PATH=$QUIL_PATH/node/test
  export QUIL_KEYS_FILE="$QUIL_NODE_PATH/.config/keys.yml"
  export QUIL_CONFIG_FILE="$QUIL_NODE_PATH/.config/config.yml"
fi
export LOG_OUTPUT_FILE="$(yq '.settings.log_file // "${HOME}/qtools/qtools.log"' $QTOOLS_CONFIG_FILE)"
source $QTOOLS_PATH/utils/index.sh

export QUIL_SERVICE_NAME="$(yq '.service.file_name // "ceremonyclient"' $QTOOLS_CONFIG_FILE)"
export QUIL_SERVICE_FILE="$SYSTEMD_SERVICE_PATH/$QUIL_SERVICE_NAME.service"
export IS_CLUSTERING_ENABLED="$(yq '.service.clustering.enabled // "false"' $QTOOLS_CONFIG_FILE)"
export IS_MASTER="$(is_master)"
export QUIL_DATA_WORKER_SERVICE_NAME="$(yq '.service.clustering.data_worker_service_name // "dataworker"' $QTOOLS_CONFIG_FILE)"
export QUIL_DATA_WORKER_SERVICE_FILE="$SYSTEMD_SERVICE_PATH/$QUIL_DATA_WORKER_SERVICE_NAME@.service"

export LINKED_BINARY_PATH="$(yq '.service.link_directory // "/usr/local/bin"' $QTOOLS_CONFIG_FILE)"
export LINKED_BINARY_NAME="$(yq '.service.link_name // "node"' $QTOOLS_CONFIG_FILE)"

export QCLIENT_CLI_NAME="$(yq '.qclient_cli_name // "qclient"' $QTOOLS_CONFIG_FILE)"
export LINKED_QCLIENT_BINARY="$LINKED_BINARY_PATH/$QCLIENT_CLI_NAME"

export LINKED_NODE_BINARY="$LINKED_BINARY_PATH/$LINKED_BINARY_NAME"

# statistics service name
export STATISTICS_SERVICE_NAME="$(yq '.scheduled_tasks.statistics.service_name // "statistics"' $QTOOLS_CONFIG_FILE)"

export OS_ARCH="$(get_os_arch)"

# Check if the service file exists, if not, run "qtools update-service"
if [ ! -f "$QUIL_SERVICE_FILE" ] && [ "$1" != "update-service" ]; then
  if [ "$IS_CLUSTERING_ENABLED" == "true" ]; then
    if [ "$IS_MASTER" == "true" ] || [ ! -f $QUIL_DATA_WORKER_SERVICE_FILE ]; then
      log "Service file not found. Running 'qtools update-service'..."
      log "Copying service file to $SYSTEMD_SERVICE_PATH..."
      qtools update-service
    fi
  fi
fi

# Function to find the script and set SERVICE_PATH
IS_GO_SCRIPT=false
IS_SH_SCRIPT=false

find_script() {
  for dir in $(find "$QTOOLS_PATH/scripts" -type d); do
    for subdir in $(find "$dir" -type d); do
      if [ "$subdir" == "qclient" ]; then
        cd $QUIL_NODE_PATH
      fi

      for subsubdir in $(find "$subdir" -type d); do
        if [ -f "$subsubdir/$1.sh" ]; then
          IS_SH_SCRIPT=true
          export SERVICE_PATH="${subsubdir%/}"
          return 0
        fi
        if [ -f "$subsubdir/$1.go" ]; then
          IS_GO_SCRIPT=true
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
  local enabled=$(yq '.settings.snapshots.enabled' $QTOOLS_CONFIG_FILE)
  [[ "$enabled" == "true" ]]
}

NODE_BINARY=$(get_current_versioned_node)

# Set environment variables based on the option
case "$1" in
  peer-id|unclaimed-balance)
    cd $QUIL_NODE_PATH
    ;;
  get-node-count|get-node-info|get-peer-info|get-token-info|get-node-version|get-peer-id|get-frame-count)
    if ! command_exists grpcurl; then
      log "Command 'grpcurl' doesn't exist, proceeding to install."
      qtools install-grpc
    fi
    ;;
  cluster-start|cluster-update-workers|cluster-stop|cluster-enable|cluster-setup|cluster-add-server|cluster-update-server|cluster-remove-server|cluster-update|status|start|stop|restart|enable|disable)
    source $QTOOLS_PATH/scripts/cluster/utils.sh
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
  echo "Invalid option: $1, use 'qtools --help' for usage information"
  exit 1
fi

# Clear screen if flag is set
if [ "$CLEAR_SCREEN" == "true" ]; then
  clear
fi

# Construct the full filename
if [ "$IS_GO_SCRIPT" == "true" ]; then
  SCRIPT="$SERVICE_PATH/$1.go"
else
  SCRIPT="$SERVICE_PATH/$1.sh"
fi

# Check if the file exists
if [ ! -f "$SCRIPT" ]; then
  echo "Error: File '$SCRIPT' does not exist."
  exit 1
fi

# Store command name and parameters for logging before shifting
COMMAND_NAME="$1"
# Copy all remaining parameters (excluding command name) for logging
# Note: --describe is already removed from $@ at this point, so it won't appear in params
COMMAND_PARAMS=("${@:2}")

# Automatically set QTOOLS_DESCRIBE to command name if not already set
# This allows internal qtools calls to automatically inherit the calling script context
if [ -z "$QTOOLS_DESCRIBE" ]; then
  export QTOOLS_DESCRIBE="$COMMAND_NAME"
fi

# Log command execution (function is available from utils/index.sh which is sourced earlier)
# QTOOLS_DESCRIBE environment variable is set earlier if --describe was provided or auto-set above
log_command_execution "$COMMAND_NAME" "${COMMAND_PARAMS[@]}"

# Now shift to remove command name for script execution
shift 1

# Source the provided script
# List of scripts that should run as root
ROOT_SCRIPTS=("install-boost-scripts" "set_cpu_performance")


if [[ " ${ROOT_SCRIPTS[@]} " =~ " $(basename "$SCRIPT" .sh) " ]]; then
  log "Running script $SCRIPT as root"
  sudo su -c "QTOOLS_PATH=$QTOOLS_PATH $SCRIPT $*" - root
else
  if [ "$IS_GO_SCRIPT" == "true" ]; then
    cd $QTOOLS_PATH/scripts/go
    go run "$SCRIPT" "$@"
  else
    source "$SCRIPT" "$@"
  fi
fi

exit 0