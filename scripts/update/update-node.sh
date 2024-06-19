#!/bin/bash

os_arch="$(get_os_arch)"
current_version="$(get_current_version)"
update_service_binary() {
    local NEW_EXECSTART="$1"
    local QUIL_BIN="$2"
    
    # Use sed to replace the ExecStart line in the service file
    sudo sed -i -e "/^ExecStart=/c\\$NEW_EXECSTART" "$QUIL_SERVICE_FILE"

    # Reload the systemd manager configuration
    sudo systemctl daemon-reload

    log "Systemctl binary version updated to $QUIL_BIN"
    
}

# Function to download all matching files if version is different
download_matching_files_if_different() {
  local available_version=$1
  local file_list=$2
  local base_url=$3

  if [[ "$current_version" != "$available_version" ]]; then
    while IFS= read -r file; do
      if [[ "$file" == *"$available_version"*"$os_arch"* ]]; then
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
    new_binary="node-$available_version-$os_arch"
    new_execstart="ExecStart=$QUIL_NODE_PATH/$new_binary \$NODE_ARGS" 
    update_service_binary $new_execstart $new_binary

    qtools restart
    set_current_version "$(get_current_version)"
  else
    echo "Versions match. No download needed."
  fi
}

# Main script execution
main() {
  # Fetch current version
  local release_version=$(fetch_release_version)
  # Fetch available files
  local available_files=$(fetch_available_files "https://releases.quilibrium.com/release")
  local available_qclient_files=$(fetch_available_files "https://releases.quilibrium.com/qclient-release")

  # Extract the version from the available files
  local available_version=$(echo "$available_files" | grep -oP 'node-([0-9\.]+)+' | head -n 1)
  local available_qclient_version=$(echo "$available_qclient_files" | grep -oP 'qclient-([0-9\.]+)+' | head -n 1)

  # Download all matching files if necessary
  download_matching_files_if_different "$release_version" "$available_files" "https://releases.quilibrium.com"
  download_matching_files_if_different "$release_version" "$available_qclient_files" "https://releases.quilibrium.com"
}

main
