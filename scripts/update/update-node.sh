#!/bin/bash


current_version="$(get_current_version)"
restart_required="false"

# Function to download all matching files if version is different
download_matching_files_if_different() {
  local available_version=$1
  local file_list=$2
  local base_url=$3

  while IFS= read -r file; do
    # only download files that are for this architecture
    if [[ "$file" == *"$OS_ARCH"* ]]; then
      local file_url="${base_url}/${file}"
      local dest_file="${QUIL_NODE_PATH}/${file}"

      if [ ! -f "$dest_file" ]; then
          log "Downloading $file_url to $dest_file"
          curl -o "$dest_file" "$file_url"
      else
          log "File $dest_file already exists"
      fi
    fi
  done <<< "$file_list"
}

# Main script execution
main() {
  # Fetch current version
  local release_version=$(fetch_release_version)
  # Fetch available files
  local available_files=$(fetch_available_files "https://releases.quilibrium.com/release")
  local available_qclient_files=$(fetch_available_files "https://releases.quilibrium.com/qclient-release")

  # Extract the version from the available files
  local available_version=$(echo "$available_files" | grep -oP 'node-([0-9\.]+)+' | head -n 1 | tr -d 'node-')
  local available_qclient_version=$(echo "$available_qclient_files" | grep -oP 'qclient-([0-9\.]+)+' | head -n 1 | tr -d 'node-')

  if [[ "$current_version" != "$available_version" ]]; then
    restart_required="true"
    rm $QUIL_CLIENT_PATH/qclient-*
    rm $QUIL_NODE_PATH/node-*
    # Download all matching files if necessary
    download_matching_files_if_different "$release_version" "$available_files" "https://releases.quilibrium.com"
    download_matching_files_if_different "$release_version" "$available_qclient_files" "https://releases.quilibrium.com"
  else 
    log "The current version ($current_version) matches ($available_version).  "
  fi
}

main

if [ "$restart_required" == "true" ]; then
  qtools update-service
  qtools restart
  sleep 10
  set_current_version "$(get_current_version)"
fi

