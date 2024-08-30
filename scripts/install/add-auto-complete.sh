#!/bin/bash
# HELP: Adds tab autocomplete for the qtools command for available commands.
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
  local curcontext="$curcontext" state line
  typeset -A opt_args

  _arguments -C \
    '1: :->command' \
    '*: :->args'

  case $state in
    command)
      local -a commands
      for dir in $QTOOLS_PATH/scripts/*/; do
        for script in $dir*.sh; do
          local cmd=$(basename $script .sh)
          local help=$(grep "# HELP:" $script | cut -d: -f2- | xargs)
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

# Add sourcing to zshrc
ZSHRC="$HOME/.zshrc"
COMPLETION_SETUP=$(cat << EOF

# QTools completion
fpath=($COMPLETION_DIR \$fpath)
autoload -Uz compinit
compinit -i
EOF
)

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