#!/bin/bash

update_service_binary() {
    local SERVICE_FILE="$1"
    local NEW_EXECSTART="$2"
    local QUIL_BIN="$3"
    
    # Update the service file if needed
    if ! check_execstart "$QUIL_SERVICE_FILE" "$NEW_EXECSTART"; then
        # Use sed to replace the ExecStart line in the service file
        sudo sed -i -e "/^ExecStart=/c\\$NEW_EXECSTART" "$QUIL_SERVICE_FILE"

        # Reload the systemd manager configuration
        sudo systemctl daemon-reload

        log "Systemctl binary version updated to $QUIL_BIN"
    fi
}

# Function to fetch available files from the release URL
fetch_available_files() {
  local url=$1
  curl -s "$url"
}

# Function to download all matching files if version is different
download_matching_files_if_different() {
  local current_version=$1
  local available_version=$2
  local os_arch=$3
  local file_list=$4
  local base_url=$5

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
    new_execstart="ExecStart=$QUIL_NODE_PATH/$new_binary" 
    update_service_binary $QUIL_SERVICE_FILE $new_execstart $new_binary

    new_debug_execstart="ExecStart=$QUIL_NODE_PATH/$QUIL_BIN --debug"
    update_service_binary $QUIL_DEBUG_SERVICE_FILE $new_debug_execstart $new_binary
    qtools restart
  else
    echo "Versions match. No download needed."
  fi
}

# Main script execution
main() {
  # Fetch current version
  local current_version=$(get_current_version)
  local release_version=$(get_release_version)
  # Fetch available files
  local available_files=$(fetch_available_files "https://releases.quilibrium.com/release")
  local available_qclient_files=$(fetch_available_files "https://releases.quilibrium.com/qclient-release")

  # Extract the version from the available files
  local available_version=$(echo "$available_files" | grep -oP 'node-\K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
  local available_qclient_version=$(echo "$available_qclient_files" | grep -oP 'qclient-\K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)

  # Set OS and ARCH (You may need to adjust these values)
  

  local os_arch="${os}-${arch}"

  # Download all matching files if necessary
  download_matching_files_if_different "$current_version" "$release_version" "$os_arch" "$available_files" "https://releases.quilibrium.com"
  download_matching_files_if_different "$current_version" "$release_version" "$os_arch" "$available_qclient_files" "https://releases.quilibrium.com"
}

main
