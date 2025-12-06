#!/bin/bash
# HELP: Updates the node, if needed, to the latest version of the node software.
# PARAM: --force: used to force an update, regardless of what is running
# Usage: qtools update-node
# Usage: qtools update-node --force

restart_required="false"
force_update="false"
auto_update="false"
is_auto_update_enabled=$(yq '.scheduled_tasks.updates.node.enabled // "false"' $QTOOLS_CONFIG_FILE)
skip_clean="false"

for param in "$@"; do
    case $param in
        --auto)
            auto_update="true"
            ;;
        --force)
            force_update="true"
            ;;
        --skip-clean)
            skip_clean="true"
            ;;
        *)
            echo "Unknown parameter: $param"
            exit 1
            ;;
    esac
done

CURRENT_NODE_VERSION=$(get_current_node_version)
CURRENT_QCLIENT_VERSION=$(get_current_qclient_version)
RELEASE_NODE_VERSION=$(fetch_node_release_version)
RELEASE_QCLIENT_VERSION=$(fetch_qclient_release_version)

# Validate that versions were fetched successfully
if [ -z "$RELEASE_NODE_VERSION" ]; then
  log "Error: Failed to fetch node release version. Exiting."
  exit 1
fi

if [ -z "$RELEASE_QCLIENT_VERSION" ]; then
  log "Error: Failed to fetch qclient release version. Exiting."
  exit 1
fi

# if this is an auto update, and auto update is disabled, exit
if [ "$auto_update" == "true" ] && [ "$is_auto_update_enabled" == "false" ]; then
  log "Node auto-update is disabled. Exiting."
  exit 0
fi

SKIP_VERSION=$(yq '.scheduled_tasks.updates.node.skip_version' $QTOOLS_CONFIG_FILE)
# otherwise we may want to skip updating to the current version for now, but on the next update we will update it
if [ "$SKIP_VERSION" != "false" ] && [ "$SKIP_VERSION" != "" ] && [ "$RELEASE_NODE_VERSION" == "$SKIP_VERSION" ]; then
  log "Skipping update for version $SKIP_VERSION"
  exit 0
fi

if [ "$CURRENT_NODE_VERSION" == "$RELEASE_NODE_VERSION" ]; then
  log "Node is already up to date. Exiting."
  exit 0
fi

qtools update-version --node-version "$RELEASE_NODE_VERSION" --qclient-version "$RELEASE_QCLIENT_VERSION"
set_current_node_version $RELEASE_NODE_VERSION
set_current_qclient_version $RELEASE_QCLIENT_VERSION

clean_old_node_files() {
    # Get a list of all files in $QUIL_NODE_PATH that don't match $release_version and remove them
    log "Removing old node files..."
    for file in "$QUIL_NODE_PATH"/*; do
      if [[ -f "$file" && ! "$file" =~ .*$RELEASE_NODE_VERSION.* && ! "$file" =~ .*\.dgst(\.sig\.[0-9]+)?$ ]]; then
        log "Removing old file: $file"
        rm -f "$file"
      fi
    done

    # Get a list of all files in $QUIL_CLIENT_PATH that don't match $release_version and remove them
    log "Removing old qclient files..."
    for file in "$QUIL_CLIENT_PATH"/*; do
      if [[ -f "$file" && ! "$file" =~ $RELEASE_QCLIENT_VERSION && ! "$file" =~ .*\.dgst(\.sig\.[0-9]+)?$ ]]; then
        log "Removing old file: $file"
        rm -f "$file"
      fi
    done
}

qtools update-service
qtools restart

if [ "$skip_clean" == "true" ]; then
  log "Skipping clean of old node files."
else
  clean_old_node_files
fi


