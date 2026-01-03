#!/bin/bash
# HELP: Adds tab autocomplete for the qtools command for available commands.
log "Adding/updating autocomplete for qtools command..."
install_package bash-completion complete

append_to_file $BASHRC_FILE "source /etc/profile.d/bash_completion.sh" false

source /etc/profile.d/bash_completion.sh

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
  
  # Remove old completion definitions
  # Remove old simple completion
  pattern="^complete -W '.*' qtools$"
  remove_lines_matching_pattern $BASHRC_FILE "$pattern"
  
  # Remove old function-based completion (multi-line removal)
  # Remove everything from _qtools_complete() to complete -F _qtools_complete qtools
  sudo sed -i '/^_qtools_complete()/,/^complete -F _qtools_complete qtools$/d' $BASHRC_FILE
  
  # Build the commands list string
  joined_script_names=$(printf "%s " "${script_names[@]}")
  
  # Generate completion function
  # Use a here-document with variable expansion for commands
  cat >> $BASHRC_FILE << QTOLS_COMPLETE_EOF

_qtools_complete() {
  local cur=\${COMP_WORDS[COMP_CWORD]}
  local prev=\${COMP_WORDS[COMP_CWORD-1]}
  
  # If we're completing the first argument (command name)
  if [ \$COMP_CWORD -eq 1 ]; then
    local commands="$joined_script_names"
    COMPREPLY=(\$(compgen -W "\$commands" -- "\$cur"))
    return 0
  fi
  
  # Get the command name (first argument)
  local cmd=\${COMP_WORDS[1]}
  
  # Find the script file
  local script_file=\$(find "\$QTOOLS_PATH/scripts" -name "\${cmd}.sh" -type f 2>/dev/null | head -1)
  
  if [ -z "\$script_file" ] || [ ! -f "\$script_file" ]; then
    return 0
  fi
  
  # Parse PARAM comments from the script
  local params=()
  
  # Extract flags (--flag or -f format) from PARAM lines
  while IFS= read -r param_line; do
    # Extract the parameter definition part (before colon, if colon exists)
    # Format examples:
    # "# PARAM: --flag: description" -> extract "--flag"
    # "# PARAM: -m, --memory: description" -> extract "-m, --memory"
    # "# PARAM: <arg>: description" -> extract "<arg>"
    
    # Extract the parameter definition part
    # Remove "# PARAM: " prefix first
    param_def=\$(echo "\$param_line" | sed 's/^# PARAM: //')
    
    # Extract part before colon (if colon exists) - this is the flag definition
    if [[ "\$param_def" =~ ^([^:]+): ]]; then
      # Has colon - extract everything before the colon
      param_def=\${BASH_REMATCH[1]}
    else
      # No colon - extract flags and comma-separated flags up to first space
      # This handles: "# PARAM: --flag desc" and "# PARAM: -m, --memory desc"
      # Extract the flag definition part (stops at first space that's not part of a flag)
      param_def=\$(echo "\$param_def" | sed -E 's/^([^[:space:]]+(,[[:space:]]*[^[:space:]]+)*).*/\1/' | head -c 200)
    fi
    
    # Trim whitespace
    param_def=\$(echo "\$param_def" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Extract flags from the parameter definition
    # Only proceed if param_def looks like it contains flags (starts with -)
    if [[ "\$param_def" =~ ^- ]]; then
      # Replace commas with spaces to handle comma-separated flags
      param_normalized=\$(echo "\$param_def" | tr ',' ' ' | sed 's/[[:space:]]\+/ /g')
      # Extract flags - match - or -- followed by alphanumerics and hyphens
      # Match at start of string or after space, end at space or end of string
      flags=\$(echo "\$param_normalized" | grep -oE '(^|[[:space:]])(-[a-zA-Z0-9][a-zA-Z0-9-]*)' 2>/dev/null | sed 's/^[[:space:]]*//')
      
      if [ -n "\$flags" ]; then
        while read -r flag; do
          # Final validation: must be a proper flag
          if [[ "\$flag" =~ ^-[a-zA-Z0-9] ]] || [[ "\$flag" =~ ^--[a-zA-Z0-9-]+ ]]; then
            params+=("\$flag")
          fi
        done <<< "\$flags"
      fi
    fi
    
    # Extract quoted values (e.g., "hourly"|"daily")
    quoted_values=\$(echo "\$param_line" | grep -oE '"([^"]+)"' 2>/dev/null | sed 's/"//g')
    if [ -n "\$quoted_values" ]; then
      while read -r value; do
        params+=("\$value")
      done <<< "\$quoted_values"
    fi
  done < <(grep "^# PARAM:" "\$script_file" 2>/dev/null)
  
  # Complete with parameters
  if [ \${#params[@]} -gt 0 ]; then
    COMPREPLY=(\$(compgen -W "\$(printf '%s ' "\${params[@]}")" -- "\$cur"))
  fi
}

complete -F _qtools_complete qtools
QTOLS_COMPLETE_EOF
fi

source $BASHRC_FILE

log "Finished adding auto-complete."