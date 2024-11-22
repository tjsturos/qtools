#!/bin/bash
# HELP: Restores store from remote backup location (if enabled in qtools config)
# PARAM: --confirm: prompts for confirmation before proceeding with the restore
# PARAM: --peer-id <string>: the peer-id to use when restoring the config directory
# PARAM: --force: bypass the backup enabled check and force the restore operation
# Usage: qtools restore-store [--confirm]

IS_BACKUP_ENABLED="$(yq '.scheduled_tasks.backup.enabled // false' $QTOOLS_CONFIG_FILE)"

PEER_ID=""
CONFIG="$QUIL_NODE_PATH/.config"
# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --config)
      shift
      CONFIG="$1"
      if [ ! -d "$CONFIG" ]; then
        echo "Error: $CONFIG directory does not exist"
        exit 1
      fi
      shift
      ;;
    --peer-id)
      shift
      PEER_ID="$1"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

IS_CLUSTERING_ENABLED="$(yq '.service.clustering.enabled // false' $QTOOLS_CONFIG_FILE)"

if [ "$IS_CLUSTERING_ENABLED" == "true" ] && [ "$(is_master)" == "false" ]; then
  echo "Clustering is enabled, skipping restore."
  exit 0
fi

REMOTE_DIR="$(yq '.scheduled_tasks.backup.remote_backup_dir' $QTOOLS_CONFIG_FILE)/store"
REMOTE_URL="$(yq '.scheduled_tasks.backup.backup_url' $QTOOLS_CONFIG_FILE)"
REMOTE_USER="$(yq '.scheduled_tasks.backup.remote_user' $QTOOLS_CONFIG_FILE)"
SSH_KEY_PATH="$(yq '.scheduled_tasks.backup.ssh_key_path' $QTOOLS_CONFIG_FILE)"

# Check if any required variable is empty
if [ "$REMOTE_DIR" == "/store" ] || [ -z "$REMOTE_URL" ] || [ -z "$REMOTE_USER" ] || [ -z "$SSH_KEY_PATH" ]; then
  echo "Error: One or more required backup settings are missing in the configuration."
  exit 1
fi

# Test SSH connection before proceeding
if ! ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 "$REMOTE_USER@$REMOTE_URL" exit 2>/dev/null; then
  echo "Error: Cannot connect to remote host. Please check your SSH configuration and network connection."
  exit 1
fi

# Check if remote directory exists
if ! ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$REMOTE_USER@$REMOTE_URL" "[ -d $REMOTE_DIR ]"; then
  echo "Error: Remote backup directory does not exist"
  exit 1
fi

# Create local store directory if it doesn't exist
mkdir -p "$CONFIG"

# Perform the rsync restore for store directory
if rsync -avzrP \
  --exclude="keys.yml" \
  --exclude="config.yml" \
  -e "ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
  "$REMOTE_USER@$REMOTE_URL:$REMOTE_DIR/" "$CONFIG/"; then
  echo "Restore of store files completed successfully."
else
  echo "Error: Restore of store files failed. Please check your rsync command and try again."
  exit 1
fi

echo "All restores completed successfully."
