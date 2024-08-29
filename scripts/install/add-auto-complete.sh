#!/bin/bash
# HELP: Adds tab autocomplete for the qtools command for available commands.
log "Adding/updating autocomplete for qtools command..."

# macOS-specific setup
brew install bash-completion

append_to_file $BASHRC_FILE '[ -f /usr/local/etc/bash_completion ] && . /usr/local/etc/bash_completion' false
COMPLETION_DIR="/usr/local/etc/bash_completion.d"

# Create the completion file
COMPLETION_FILE="$COMPLETION_DIR/qtools"

# Define the directory to search
search_directory="$QTOOLS_PATH/scripts"

# Check if the directory exists
if [[ ! -d "$search_directory" ]]; then
  log "Directory '$search_directory' does not exist."
  exit 1
fi

# Find all .sh files in the directory and its subdirectories
sh_files=$(find "$search_directory" -type f -name "*.sh")

# Check if any .sh files were found
if [[ -z "$sh_files" ]]; then
  log "No .sh files found in '$search_directory'."
else
  # Initialize an array to hold the script names without the .sh extension
  script_names=()

  # Loop through each found .sh file
  while IFS= read -r file; do
    # Get the filename without the directory path
    filename=$(basename "$file")
    # Remove the .sh extension and add to the array
    script_names+=("${filename%.sh}")
  done <<< "$sh_files"
  
  # Join the script names with a space
  joined_script_names=$(printf "%s " "${script_names[@]}")
  
  # Create the completion script
  cat > "$COMPLETION_FILE" << EOF
_qtools()
{
    local cur prev opts
    COMPREPLY=()
    cur="\${COMP_WORDS[COMP_CWORD]}"
    prev="\${COMP_WORDS[COMP_CWORD-1]}"
    opts="$joined_script_names"

    COMPREPLY=( \$(compgen -W "\${opts}" -- \${cur}) )
    return 0
}
complete -F _qtools qtools
EOF

  log "Created auto-completion file: $COMPLETION_FILE"
fi

# Source the completion file
append_to_file $BASHRC_FILE "source $COMPLETION_FILE" false

log "Finished adding auto-complete. Please restart your shell or source your rc file to enable it."