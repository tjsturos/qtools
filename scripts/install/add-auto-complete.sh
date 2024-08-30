#!/bin/bash
# HELP: Adds tab autocomplete for the qtools command for available commands.
log "Adding/updating autocomplete for qtools command..."

# macOS-specific setup
brew install bash-completion@2

# Use a user-specific directory for completion scripts
COMPLETION_DIR="$HOME/.zsh_completion"
mkdir -p "$COMPLETION_DIR"

# Create the completion file
COMPLETION_FILE="$COMPLETION_DIR/_qtools"

# Create the completion script
cat > "$COMPLETION_FILE" << 'EOF'
#compdef qtools

_qtools() {
  local state

  _arguments \
    '1: :->command'\
    '*: :->args'

  case $state in
    (command)
      local -a subcommands
      subcommands=($(qtools --help | grep -oE '^ +- [a-zA-Z0-9_-]+' | awk '{print $2}'))
      _describe -t commands 'qtools commands' subcommands
      ;;
    (args)
      case $words[2] in
        update-hostname)
          _message 'hostname'
          ;;
        # Add more cases for other commands that need specific argument completion
        *)
          _files
          ;;
      esac
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

log "Created auto-completion file: $COMPLETION_FILE"
log "Updated $ZSHRC with completion setup"
log "Finished adding auto-complete. Please restart your shell or run 'source $ZSHRC' to enable it."