#!/bin/bash

apt-get install bash-completion

append_to_file ~/.bashrc "source /etc/profile.d/bash_completion.sh"

source /etc/profile.d/bash_completion.sh

# Define the directory to search
search_directory="scripts"

# Check if the directory exists
if [[ ! -d "$search_directory" ]]; then
  echo "Directory '$search_directory' does not exist."
  exit 1
fi

# Find all .sh files in the directory and its subdirectories
sh_files=$(find "$search_directory" -type f -name "*.sh")

# Check if any .sh files were found
if [[ -z "$sh_files" ]]; then
  echo "No .sh files found in '$search_directory'."
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
  
  append_to_file ~/.bashrc "complete -W '$joined_script_names' qtools"
fi

source ~/.bashrc