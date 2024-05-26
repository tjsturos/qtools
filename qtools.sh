#!/bin/bash

# Check if the parameter is provided
usage() {
  echo "Usage: $0 <option>"
  echo "Note that autocomplete should be installed.  If it doesn't work, run 'qtools add-auto-complete' and try again."
  echo ""
  echo "Options:"

  echo "Installation and Updates:"
  echo "  complete-install       - Do a full install of the ceremony client."
  echo "  update-node            - Perform an update on the ceremony client."
  echo "  update-qtools          - Update the qTools code."
  echo "  install-go             - Install Go and setup Go environment."
  echo "  install-node-binary    - Install node binary for this node."
  echo "  install-qclient-binary - Install qClient binary for this node."
  echo "  install-grpc           - Install gRPC on the server for querying node info."
  echo "  import-store           - Import the store snapshot from Cherry Servers."

  echo "Configuration:"
  echo "  make-backup            - Make a local-only backup (on this server) of the config.yml and keys.yml files."
  echo "  restore-backup         - Restore a local-only backup (on this server) of the config.yml and keys.yml files."
  echo "  modify-config          - Perform necessary changes to the config.yml file (upon creation or already created)."

  echo "System Setup:"
  echo "  remove-docker          - Remove Docker from this server."
  echo "  setup-cron             - Install necessary scheduled tasks for the node."
  echo "  setup-firewall         - Install firewall for this server."
  echo "  disable-ssh-passwords  - Disable logging into this server via password."

  echo "Node Management:"
  echo "  purge-node             - Remove Node and re-install (performs local-only backup of config files)."
  echo "  start                  - Start the Quilibrium node service."
  echo "  restart                - Restart the Quilibrium node service."
  echo "  stop                   - Stop the Quilibrium node service."
  echo "  enable                 - Enable the Quilibrium node service (for starting on reboot)."
  echo "  status                 - Get the status of the Quilibrium node service."
  echo "  view-log               - View the log from the Quilibrium node service."

  echo "Tooling:"
  echo "  create-qtools-symlink  - Create a symlink for 'qtools' to /usr/local/bin."
  echo "  add-auto-complete      - Add autocomplete for the 'qtools' command."

  echo "Network Information:"
  echo "  get-token-info         - Get network information on tokens."
  echo "  get-peer-info          - Get network information on peers."
  echo "  get-node-count         - Get the number of nodes on the network."
  echo "  get-node-info          - Get information about this node."
  echo "  get-peer-id            - Get the peer ID of this node."
  echo "  get-node-version       - Get the version of this node."

  exit 1
}

if [ -z "$1" ]; then
  usage
fi

# Load environment variables to be made available in all scripts
export DEBIAN_FRONTEND="noninteractive"
export QUIL_PATH=$HOME/ceremonyclient
export QUIL_NODE_PATH=$QUIL_PATH/node
export QUIL_CLIENT_PATH=$QUIL_PATH/client
export QUIL_GO_NODE_BIN=$HOME/go/bin/node
export QTOOLS_BIN_PATH=/usr/local/bin/qtools
export QUIL_SERVICE_PATH=/lib/systemd/system
export QUIL_SERVICE_FILE="$QUIL_SERVICE_PATH/ceremonyclient.service"

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

install_package inotify-tools inotifywait

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

# Set environment variables based on the option
case "$1" in
  remove-docker|purge|disable-ssh-passwords)
    export SERVICE_PATH="$QTOOLS_PATH/scripts"
    ;;
  start|stop|status|enable|restart)
    export SERVICE_PATH="$QTOOLS_PATH/scripts/commands"
    ;;
  update-node|update-qtools)
    export SERVICE_PATH="$QTOOLS_PATH/scripts/update"
    ;;
  install-go|install-qclient-binary|complete-install|install-node-binary|setup-cron|modify-config|create-qtools-symlink|setup-firewall|add-auto-complete|install-grpc|import-store)
    export SERVICE_PATH="$QTOOLS_PATH/scripts/install"
    ;;
  make-backup|restore-backup)
    export SERVICE_PATH="$QTOOLS_PATH/scripts/backup"
    ;;
  view-log)
    export SERVICE_PATH="$QTOOLS_PATH/scripts/diagnostics"
    ;;
  get-node-count|get-node-info|get-peer-info|get-token-info|get-node-version|get-peer-id)
    if ! command_exists grpcurl; then
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