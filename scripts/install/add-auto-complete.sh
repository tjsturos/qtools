#!/usr/bin/env zsh
# HELP: Adds tab autocomplete for the qtools command for available commands.

if [ -n "$BASH_VERSION" ]; then
    echo "This script must be run in zsh, not bash."
    exit 1
fi

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

set -x  # Enable debug mode

if [ -z "$QTOOLS_PATH" ]; then
    echo "Error: QTOOLS_PATH is not set. Please set it before running this script."
    exit 1
fi

log "Adding/updating autocomplete for qtools command..."

# macOS-specific setup
brew install bash-completion

# Use a user-specific directory for completion scripts
COMPLETION_DIR="$HOME/.zsh_completion"
mkdir -p "$COMPLETION_DIR"

# Create the completion file
COMPLETION_FILE="$COMPLETION_DIR/_qtools"

# Create the completion script
cat > "$COMPLETION_FILE" << 'EOF'
#compdef qtools

_qtools() {
  echo "Debug: _qtools function called with args: $@" >&2
  echo "Debug: QTOOLS_PATH=$QTOOLS_PATH" >&2
  echo "Debug: Current directory: $(pwd)" >&2
  
  local curcontext="$curcontext" state line
  typeset -A opt_args

  _arguments -C \
    '1: :->command' \
    '*: :->args'

  case $state in
    command)
      echo "Debug: Entering command state" >&2
      local -a commands
      for dir in "$QTOOLS_PATH"/scripts/*/; do
        echo "Debug: Processing directory: $dir" >&2
        for script in "$dir"*.sh; do
          echo "Debug: Processing script: $script" >&2
          local cmd=$(basename "$script" .sh)
          local help=$(grep "# HELP:" "$script" | cut -d: -f2- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
          echo "Debug: cmd=$cmd, help=$help" >&2
          if [[ -n $help ]]; then
            commands+=("$cmd:$help")
          else
            commands+=("$cmd")
          fi
        done
      done
      _describe -t commands 'qtools commands' commands
      ;;
    args)
      local cmd=$words[2]
      local script="$QTOOLS_PATH/scripts/*/$cmd.sh"
      if [[ -f $script ]]; then
        local -a params
        while IFS= read -r line; do
          if [[ $line =~ ^#\ PARAM:\ (.+)$ ]]; then
            params+=("${BASH_REMATCH[1]}")
          fi
        done < "$script"
        if (( ${#params[@]} > 0 )); then
          _values 'parameters' $params
        else
          _files
        fi
      fi
      ;;
  esac
}

compdef _qtools qtools
EOF

# After creating the completion file, add:
log "Contents of the completion file:"
cat "$COMPLETION_FILE"

# Add sourcing to zshrc
ZSHRC="$HOME/.zshrc"
COMPLETION_SETUP="
# QTools completion
fpath=($COMPLETION_DIR \$fpath)
autoload -Uz compinit
compinit -i
"

if ! grep -q "# QTools completion" "$ZSHRC"; then
  echo "$COMPLETION_SETUP" >> "$ZSHRC"
fi

# Add QTOOLS_PATH to zshrc if not already present
if ! grep -q "export QTOOLS_PATH=" "$ZSHRC"; then
  echo "export QTOOLS_PATH=\"$QTOOLS_PATH\"" >> "$ZSHRC"
fi

log "Created auto-completion file: $COMPLETION_FILE"
log "Updated $ZSHRC with completion setup and QTOOLS_PATH"
log "Finished adding auto-complete. Please restart your shell or run 'source $ZSHRC' to enable it."

set +x  # Disable debug mode