#!/bin/bash

# Check if the parameter is provided
usage() {
  echo "Usage: $0 <option>"
  echo "Options:"
  echo "  complete-install       - Do a full install of the ceremony client."
  echo "  update-node            - Perform an update on the ceremony client."
  echo "  make-backup            - Make a local-only backup (on this server) of the config.yml and keys.yml files."
  echo "  restore-backup         - Make a local-only backup (on this server) of the config.yml and keys.yml files."
  echo "  modify-config          - Perform necessary changes to the config.yml file (upon creation or already created)."
  echo "  remove-docker          - Remove Docker from this server."
  echo "  setup-cron             - Install neccesary scheduled tasks for the node"
  echo "  setup-firewall         - Install firewall for this server"
  echo "  install-go             - Install Go and setup Go environment"
  echo "  purge-node             - Remove Node and re-install (performs local-only back of config files)"
  echo "  install-node-binary    - Install node binary for this node"
  echo "  install-qclient-binary - Install qClient binary for this node"
  echo "  create-qtools-symlink  - Create a symlink for 'qtools' to /usr/local/bin"
  echo "  add-auto-complete      - Add autocomplete for the 'qtools' command"
  
  exit 1
}

if [ -z "$1" ]; then
  usage
fi

# Load environment variables to be made available in all scripts
export QUIL_PATH=/root/ceremonyclient
export QUIL_NODE_PATH=$QUIL_PATH/node
export QUIL_CLIENT_PATH=$QUIL_PATH/client
export QUIL_GO_NODE_BIN=/root/go/bin/node
export QTOOLS_BIN_PATH=/usr/local/bin/qtools

source add-tool-path.sh

# The rest of these scripts rely on $QTOOLS_PATH, so fail if not found.
if [ -z "$QTOOLS_PATH" ]; then
  echo "Couldn't find QTOOLS_PATH. Failing early."
  exit 1
fi

# common utils for scripts
source $QTOOLS_PATH/utils.sh

# Remaining scripts need existance of the QTOOLS_BIN_PATH binary
if [ ! -f "$QTOOLS_BIN_PATH" ]; then
  # Attempt to install it.
  source $QTOOLS_PATH/scripts/install/create-qtools-symlink.sh

  if [ ! -f "$QTOOLS_BIN_PATH" ]; then
    log "$QTOOLS_BIN_PATH did not exist. Attempted to install, but failed. This is required to proceed. Try \"ln -s $QTOOLS_PATH/qtools.sh /usr/local/bin/qtools\" manually."
    exit 1
  fi
fi

# Set environment variables based on the option
case "$1" in
  remove-docker|update-node|purge)
    export SERVICE_PATH="$QTOOLS_PATH/scripts"
    ;;
  install-go|install-qclient-binary|complete-install|install-node-binary|setup-cron|modify-config|create-qtools-symlink|setup-firewall|add-auto-complete)
    export SERVICE_PATH="$QTOOLS_PATH/scripts/install"
    ;;
  make-backup|restore-backup)
    export SERVICE_PATH="$QTOOLS_PATH/scripts/backup"
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