#!/bin/bash
echo "Initializing qtools"

LOG_OUTPUT_FILE=$QTOOLS_PATH/logs/qtools.log

source $QTOOLS_PATH/utils/index.sh
export OS_ARCH=$(get_os_arch)

if [ ! -f "$QTOOLS_CONFIG_FILE" ]; then
  cp $QTOOLS_PATH/config.sample.yml $QTOOLS_PATH/config.yml
  echo "Copied the default config file (config.sample.yml) to make the initial config.yml file."
  echo "To edit, use 'qtools edit-qtools-config' command"

fi

if ! command -v "yq" >/dev/null 2>&1; then
  source $QTOOLS_PATH/scripts/install/install-yq.sh
  source ~/.bashrc
  if ! command -v "yq" >/dev/null 2>&1; then
    echo "Could not install command 'yq'.  Please try again or install manually."
    exit 1
  fi
fi

# Set the user and working directory in the config file
cd $QTOOLS_PATH

qtools config set-value user "$USER" --quiet
qtools config set-value service.working_dir "$HOME/ceremonyclient/node" --quiet

install_package colordiff colordiff
install_package jq jq
install_package base58 base58
install_package dnsutils dig
install_package rsync rsync
install_package ufw ufw
install_package bc bc
install_package crontab cron
install_package curl curl

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
fi

# Update the INIT_COMPLETE file with the current date and time
sudo touch $QTOOLS_PATH/INIT_COMPLETE
date | sudo tee $QTOOLS_PATH/INIT_COMPLETE > /dev/null

source $QTOOLS_PATH/qtools.sh add-auto-complete