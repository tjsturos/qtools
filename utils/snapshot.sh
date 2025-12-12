#!/bin/bash

# Redundant if called via qtools.sh as utils.sh sources this already,
# but this is a safeguard if this script is called directly
# Source the hardware.sh file
source $QTOOLS_PATH/utils/hardware.sh

# Function to create and update snapshot
update_snapshot() {
  local snapshot_file="$QUIL_NODE_PATH/.config/QTOOLS_NODE_CHANGES"
  local current_snapshot=$(get_current_snapshot)
  local timestamp=$(date +%s)

  if [ ! -f "$snapshot_file" ]; then
    echo "$timestamp SNAPSHOT $current_snapshot" > "$snapshot_file"
    log "Initial snapshot created."
  else
    local last_snapshot=$(get_last_snapshot "$snapshot_file")
    if [ "$current_snapshot" != "$last_snapshot" ]; then
      local changes=$(compare_snapshots "$last_snapshot" "$current_snapshot")
      echo "$timestamp $changes" >> "$snapshot_file"
      echo "$timestamp SNAPSHOT $current_snapshot" >> "$snapshot_file"
      log "Snapshot updated with changes: $changes"
    else
      log "No changes detected in snapshot."
    fi
  fi
}

# Function to get the last snapshot from the file
get_last_snapshot() {
  local file="$1"
  tail -n 1 "$file" | sed 's/^[0-9]* SNAPSHOT //'
}

# Function to get current snapshot
get_current_snapshot() {
  local cpu=$(get_model_name)
  local ram=$(get_ram)
  local hdd=$(get_hdd_space)
  local cores=$(get_cores)
  local threads=$(get_threads)
  local hyperthreading=$(get_is_hyperthreading_enabled)
  local peer_id=$(qtools --describe "snapshot" peer-id)
  echo "CPU:$cpu RAM:$ram HDD:$hdd Cores:$cores Threads:$threads Hyperthreading:$hyperthreading PeerID:$peer_id"
}

# Function to compare snapshots and return changes
compare_snapshots() {
  local old_snapshot="$1"
  local new_snapshot="$2"
  local changes=""

  IFS=':' read -ra old_parts <<< "$old_snapshot"
  IFS=':' read -ra new_parts <<< "$new_snapshot"

  for i in "${!old_parts[@]}"; do
    if [ "${old_parts[$i]}" != "${new_parts[$i]}" ]; then
      local key=$(echo "${old_parts[$i]}" | cut -d' ' -f1)
      local new_value=$(echo "${new_parts[$i]}" | cut -d' ' -f2-)
      changes+="$key changed: $new_value "
    fi
  done

  echo "$changes"
}
