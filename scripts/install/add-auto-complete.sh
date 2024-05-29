#!/bin/bash

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
  # Join the script names with a space
  joined_script_names=$(printf "%s " "${script_names[@]}")
  
  pattern="^complete -W '.*' qtools$"
  remove_lines_matching_pattern $BASHRC_FILE "$pattern"
  append_to_file $BASHRC_FILE "complete -W '$joined_script_names' qtools" false
fi

source $BASHRC_FILE