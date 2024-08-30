#!/bin/bash
echo "Initializing qtools for macOS"

source "$QTOOLS_PATH/utils.sh"

if [[ ! -f "$QTOOLS_CONFIG_FILE" ]]; then
  cp "$QTOOLS_PATH/config.sample.yml" "$QTOOLS_PATH/config.yml"
  echo "Copied the default config file (config.sample.yml) to make the initial config.yml file."  
  echo "To edit, use 'qtools edit-qtools-config' command"
fi

# Install Homebrew if not already installed
if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Add Homebrew to PATH for the current session
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Install required packages using Homebrew
brew install yq colordiff jq

# Update config file using yq
yq -i ".user = \"$USER\"" "$QTOOLS_CONFIG_FILE"
yq -i ".service.working_dir = \"$HOME/ceremonyclient/node\"" "$QTOOLS_CONFIG_FILE"

# Remaining scripts need existence of the QTOOLS_BIN_PATH binary
if [[ ! -L "$QTOOLS_BIN_PATH" ]]; then
  # Attempt to install it.
  log "$QTOOLS_BIN_PATH not found. Attempting to install."
  source "$QTOOLS_PATH/scripts/install/create-qtools-symlink.sh"

  if [[ ! -L "$QTOOLS_BIN_PATH" ]]; then
    log "Attempted to install $QTOOLS_BIN_PATH, but failed. This is required to proceed. Try \"sudo ln -s $QTOOLS_PATH/qtools.sh /usr/local/bin/qtools\" manually."
    exit 1
  else
    log "$QTOOLS_BIN_PATH installed successfully."
  fi
fi

source "$QTOOLS_PATH/qtools.sh" add-auto-complete