#!/bin/bash

if [ -z "$QTOOLS_PATH" ]; then
  # Define TOOL_PATH (example path, change as needed)
  export QTOOLS_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  # Change group of the directory and its contents
  groupadd $GROUP
  chgrp -R "$GROUP" $QTOOLS_PATH
  if [ $? -ne 0 ]; then
      echo "Failed to change group of $DIRECTORY"
      exit 1
  fi

  # Add TOOL_PATH definition to ~/.bashrc
  echo "export QTOOLS_PATH=\"$QTOOLS_PATH\"" >> ~/.bashrc

  # Reload ~/.bashrc to apply changes
  source ~/.bashrc
fi