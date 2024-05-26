#!/bin/bash

if grep -qE "$pattern" "$bashrc_file"; then
  echo "Pattern found in .bashrc. Removing it..."
  # Use sed to remove the line containing the pattern
  sed -i "/$pattern/d" "$bashrc_file"
  echo "Pattern removed from .bashrc."
fi

apt-get install bash-completion

append_to_file ~/.bashrc "source /etc/profile.d/bash_completion.sh"

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
  remove_lines_matching_pattern "~/.bashrc" "$pattern"
  append_to_file ~/.bashrc "complete -W '$joined_script_names' qtools"
fi

source ~/.bashrc