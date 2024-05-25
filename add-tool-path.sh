#!/bin/bash

if [ -z "$QTOOLS_PATH" ]; then
  # Define TOOL_PATH (example path, change as needed)
  export QTOOLS_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  # Add TOOL_PATH definition to ~/.bashrc
  echo "export QTOOLS_PATH=\"$QTOOLS_PATH\"" >> ~/.bashrc

  # Reload ~/.bashrc to apply changes
  source ~/.bashrc
fi