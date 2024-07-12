#!/bin/bash
echo "Initializing qtools"

if [ ! -f "$QTOOLS_CONFIG_FILE" ]; then
  cp $QTOOLS_PATH/config.sample.yml $QTOOLS_PATH/config.yml
  echo "Copied the default config file (config.sample.yml) to make the initial config.yml file."  
  echo "To edit, use 'qtools edit-qtools-config' command"
  yq ".user = \"$USER\"" $QTOOLS_CONFIG_FILE
  yq ".service.working_dir = \"$HOME/ceremonyclient/node\"" $QTOOLS_CONFIG_FILE
fi

if ! command -v "yq" >/dev/null 2>&1; then
  echo "Installing yq"
  source $QTOOLS_PATH/scripts/install/install-yq.sh
  if ! command -v "yq" >/dev/null 2>&1; then
    echo "Could not install command 'yq'.  Please try again or install manually."
    exit 1
  fi
else 
  echo "yq already installed"
fi
echo "Config file: $QTOOLS_CONFIG_FILE"
echo "Log file: $(yq '.settings.log_file' $QTOOLS_CONFIG_FILE)"
export LOG_OUTPUT_FILE="$(yq '.settings.log_file' $QTOOLS_CONFIG_FILE)"
echo "$LOG_OUTPUT_FILE"
source $QTOOLS_PATH/utils.sh
echo "after utils"

log "installing requisite software"
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
  fi
else 
   log "qtools link already exists"
fi

log "Going to install autocomplete"
source $QTOOLS_PATH/qtools.sh add-auto-complete