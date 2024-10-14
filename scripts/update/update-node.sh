#!/bin/bash
# HELP: Updates the node, if needed, to the latest version of the node software.
# PARAM: --force: used to force an update, regardless of what is running
# Usage: qtools update-node
# Usage: qtools update-node --force

current_version="$(get_current_version)"
restart_required="false"
force_update="false"
auto_update="false"
is_auto_update_enabled=$(yq '.scheduled_tasks.updates.node.enabled // "false"' $QTOOLS_CONFIG_FILE)

for param in "$@"; do
    case $param in
        --auto)
            auto_update="true"
            ;;
        --force)
            force_update="true"
            ;;
        *)
            echo "Unknown parameter: $param"
            exit 1
            ;;
    esac
done

# Function to download all matching files if version is different
download_matching_files_if_different() {
  local available_version=$1
  local file_list=$2
  local base_url=$3
  local output_path=$4

  while IFS= read -r file; do
    # only download files that are for this architecture
    if [[ "$file" == *"$OS_ARCH"* ]]; then
      local file_url="${base_url}/${file}"
      local dest_file="${output_path}/${file}"

      if [ ! -f "$dest_file" ]; then
          log "Downloading $file_url to $dest_file"
          curl -o "$dest_file" "$file_url"
      else
          log "File $dest_file already exists"
      fi
    fi
  done <<< "$file_list"
}

link_node_binary() {
  if [ -l $QUIL_NODE_BIN ]; then
    sudo rm $QUIL_NODE_BIN
  fi
  sudo ln -sf $QUIL_NODE_PATH/$(get_release_node_version) $QUIL_NODE_BIN
}

link_qclient_binary() {
  if [ -l $QUIL_QCLIENT_BIN ]; then
    sudo rm $QUIL_QCLIENT_BIN
  fi
  sudo ln -sf $QUIL_CLIENT_PATH/$(get_versioned_qclient) $QUIL_QCLIENT_BIN
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

  if [[ "$current_version" != "$available_version" ]] || [[ $force_update == "true" ]]; then
    restart_required="true"
    # Download all matching files if necessary
    download_matching_files_if_different "$release_version" "$available_files" "https://releases.quilibrium.com" "$QUIL_NODE_PATH"
    sudo chmod +x $QUIL_NODE_PATH/$(get_release_node_version)
    download_matching_files_if_different "$release_version" "$available_qclient_files" "https://releases.quilibrium.com" "$QUIL_CLIENT_PATH"
    sudo chmod +x $QUIL_CLIENT_PATH/$(get_versioned_qclient)

    # Get a list of all files in $QUIL_NODE_PATH that don't match $release_version and remove them
    log "Removing old node files..."
    for file in "$QUIL_NODE_PATH"/*; do
      if [[ -f "$file" && ! "$file" =~ .*$release_version.* ]]; then
        log "Removing old file: $file"
        rm -f "$file"
      fi
    done

    # Get a list of all files in $QUIL_CLIENT_PATH that don't match $release_version and remove them
    log "Removing old qclient files..."
    for file in "$QUIL_CLIENT_PATH"/*; do
      if [[ -f "$file" && ! "$file" =~ $release_version ]]; then
        log "Removing old file: $file"
        rm -f "$file"
      fi
    done
  else 
    log "The current version ($current_version) matches ($available_version).  "
  fi
}

if [ "$auto_update" == "true" ] && [ "$is_auto_update_enabled" == "false" ]; then
  log "Node auto-update is disabled. Exiting."
  exit 0
fi

main

if [ "$restart_required" == "true" ]; then
  link_node_binary
  link_qclient_binary
  qtools update-service
  qtools restart
  sleep 10
  set_current_version "$(get_current_version)"
fi

