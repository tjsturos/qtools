#!/bin/bash

# Check if the parameter is provided
usage() {
  echo "Usage: $0 <option>"
  echo "Note that autocomplete should be installed.  If it doesn't work, run 'qtools add-auto-complete' and try again."
  echo ""
  echo "Options:"

  echo "Installation and Updates:"
  echo "  complete-install         - Do a full install of the ceremony client."
  echo "  update-node              - Perform an update on the ceremony client."
  echo "  self-update              - Update the qtools code."
  echo "  update-kernel            - Update the Linux kernel on this server."
  echo "  update-service           - Update the Systemd services (live and debug)."
  echo "  install-go               - Install Go and setup Go environment."
  echo "  install-yq               - Install yq library."
  echo "  install-grpc             - Install gRPC on the server for querying node info."  
  echo "  install-qclient          - Download QClient binary from releases site."   
  echo "  install-node-binary      - Download Node binary (and signatures) from releases site."   

  echo "Configuration:"
  echo "  make-backup              - Make a local-only backup (on this server) of the config.yml and keys.yml files."
  echo "  restore-backup           - Restore a local-only backup (on this server) of the config.yml and keys.yml files."
  echo "  modify-config            - Perform necessary changes to the config.yml file (upon creation or already created)."
  echo "  backup-store             - Make a backup of the store (and config files) to a remote server"

  echo "System Setup:"
  echo "  remove-docker            - Remove Docker from this server."
  echo "  install-cron             - Install necessary scheduled tasks for the node."
  echo "  setup-firewall           - Install firewall for this server."
  echo "  disable-ssh-passwords    - Disable logging into this server via password."

  echo "Node Management:"
  echo "  purge-node               - Remove Node and re-install (performs local-only backup of config files)."
  echo "  start                    - Start the Quilibrium node service."
  echo "  restart                  - Restart the Quilibrium node service."
  echo "  stop                     - Stop the Quilibrium node service."
  echo "  enable                   - Enable the Quilibrium node service (for starting on reboot)."
  echo "  status                   - Get the status of the Quilibrium node service."
  echo "  debug                    - Start the node in debug mode."
  echo "  view-log                 - View the log from the Quilibrium node service."
  echo "  view-debug-log           - View the debug log from the Quilibrium DEBUG node service."
  echo "  get-ports-listening      - Detect if listening on ports 22, 443, 8336, 8337."
  echo "  detect-bootstrap-peers   - Detect if bootstrap peers know of node."
  echo "  record-unclaimed-rewards - Record the unclaimed rewards balance to a CSV file."

  echo "Tooling:"
  echo "  create-qtools-symlink    - Create a symlink for 'qtools' to /usr/local/bin."
  echo "  add-auto-complete        - Add autocomplete for the 'qtools' command."

  echo "Network Information:"
  echo "  get-token-info           - Get network information on tokens."
  echo "  get-peer-info            - Get network information on peers."
  echo "  get-node-count           - Get the number of nodes on the network."
  echo "  get-node-info            - Get information about this node."
  echo "  get-peer-id              - Get the Peer ID of this node (uses both grpcurl and node commands)."
  echo "  get-node-version         - Get the version of this node."
  echo "  get-frame-count          - Get the current frame (maxFrame) of this node."
  
  echo "Node Commands"
  echo "  node-get-peer-id         - Get the Peer ID without using grpcurl."
  echo "  node-get-rewards-balance - Get the rewards balance."

  echo "Common command shortcuts:"
  echo "  edit-qtools-config              - Edit the qTools config file."
  echo "  edit-quil-config              - Edit the Quil node config file."

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

# Get the directory where the script is located
QTOOLS_PATH=$(dirname "$SCRIPT_PATH")

# common utils for scripts
source $QTOOLS_PATH/utils.sh

if ! command_exists 'yq'; then
  source $QTOOLS_PATH/scripts/install/install-yq.sh
  if ! command_exists 'yq'; then
    log "Could not install command 'yq'.  Please try again or install manually."
    exit 1
  fi
fi

export QTOOLS_CONFIG_FILE=$QTOOLS_PATH/config.yml

if [ ! -f "$QTOOLS_CONFIG_FILE" ]; then
  cp $QTOOLS_PATH/config.sample.yml $QTOOLS_PATH/config.yml
  log "Copied the default config file (config.sample.yml) to make the initial config.yml file."  
  log "To edit, use 'qtools edit-qtools-config' command"
fi

install_package inotify-tools inotifywait
install_package colordiff colordiff
install_package jq jq
install_package base58 base58

# Remaining scripts need existance of the QTOOLS_BIN_PATH binary
if [ ! -L "$QTOOLS_BIN_PATH" ]; then
  # Attempt to install it.
  log "$QTOOLS_BIN_PATH not found.  Attempting to install."
  source $QTOOLS_PATH/scripts/install/create-qtools-symlink.sh

  if [ ! -L "$QTOOLS_BIN_PATH" ]; then
    log "Attempted to install $QTOOLS_BIN_PATH, but failed. This is required to proceed. Try \"ln -s $QTOOLS_PATH/qtools.sh /usr/local/bin/qtools\" manually."
    exit 1
  else
    log "$QTOOLS_BIN_PATH installed successfully."
  fi
fi



export LOG_OUTPUT_FILE="$(yq '.settings.log_file' $QTOOLS_CONFIG_FILE)"
export QUIL_SERVICE_NAME="$(yq '.service.file_name' $QTOOLS_CONFIG_FILE)"
export QUIL_SERVICE_FILE="$SYSTEMD_SERVICE_PATH/$QUIL_SERVICE_NAME@.service"
export OS_ARCH="$(get_os_arch)"

# Set environment variables based on the option
case "$1" in
  remove-docker|purge|disable-ssh-passwords)
    export SERVICE_PATH="$QTOOLS_PATH/scripts"
    ;;
  edit-qtools-config|edit-quil-config)
    export SERVICE_PATH="$QTOOLS_PATH/scripts/shortcuts"
    ;;
  start|stop|status|enable|restart)
    export SERVICE_PATH="$QTOOLS_PATH/scripts/commands"
    ;;
  update-node|self-update|update-kernel|update-service)
    export SERVICE_PATH="$QTOOLS_PATH/scripts/update"
    ;;
  install-go|install-node-binary|install-yq|complete-install|install-cron|modify-config|create-qtools-symlink|setup-firewall|add-auto-complete|install-grpc|install-qclient)
    export SERVICE_PATH="$QTOOLS_PATH/scripts/install"
    ;;
  make-backup|restore-backup|backup-store)
    export SERVICE_PATH="$QTOOLS_PATH/scripts/backup"
    ;;
  view-log|debug|view-debug-log|get-ports-listening|detect-bootstrap-peers|record-unclaimed-rewards)
    export SERVICE_PATH="$QTOOLS_PATH/scripts/diagnostics"
    ;;
  node-get-peer-id|node-get-reward-balance)
    cd $QUIL_NODE_PATH
    export QUIL_BIN=$(get_versioned_node)
    export SERVICE_PATH="$QTOOLS_PATH/scripts/node-commands"
    ;;
  get-node-count|get-node-info|get-peer-info|get-token-info|get-node-version|get-peer-id|get-frame-count)
    if ! command_exists grpcurl; then
      log "Command 'grpcurl' doesn't exist, proceeding to install."
      qtools install-grpc
    fi
    export SERVICE_PATH="$QTOOLS_PATH/scripts/grpc"
    ;;
  *)
    echo "Invalid option: $1"
    usage
    ;;
esac

# Construct the full filename
SCRIPT="$SERVICE_PATH/$1.sh"

# Check if the file exists
if [ ! -f "$SCRIPT" ]; then
  echo "Error: File '$SCRIPT' does not exist."
  exit 1
fi

# Source the provided script
source "$SCRIPT"