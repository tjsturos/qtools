#!/bin/bash
# HELP: Backs up store (if enabled in qtools config) to remote location.
# PARAM: --confirm: prompts for confirmation before proceeding with the backup
# PARAM: --peer-id <string>: the peer-id to use when backing up the config directory.
# PARAM: --force: bypass the backup enabled check and force the backup operation.
# Usage: qtools backup-store [--confirm]


IS_BACKUP_ENABLED="$(yq '.scheduled_tasks.backup.enabled // false' $QTOOLS_CONFIG_FILE)"

PEER_ID=""
CONFIG="$QUIL_NODE_PATH/.config"
RESTART_NODE=false

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --restart)
      RESTART_NODE=true
      shift
      ;;
    --config)
      shift
      CONFIG="$1"
      if [ ! -d "$CONFIG" ] || [ ! -d "$CONFIG/store" ] || [ -z "$(find "$CONFIG/store" -name "*.sst" 2>/dev/null)" ]; then
        echo "Error: $CONFIG does not exist or does not contain a valid store directory with .sst files"
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
  echo "Clustering is enabled, skipping backup."
  exit 0
fi

if [ -z "$PEER_ID" ]; then
  PEER_ID="$(qtools peer-id)"
fi

echo "Stopping node"
qtools stop

REMOTE_DIR="$(yq '.scheduled_tasks.backup.remote_backup_dir' $QTOOLS_CONFIG_FILE)/store/$PEER_ID"
REMOTE_URL="$(yq '.scheduled_tasks.backup.backup_url' $QTOOLS_CONFIG_FILE)"
REMOTE_USER="$(yq '.scheduled_tasks.backup.remote_user' $QTOOLS_CONFIG_FILE)"
SSH_KEY_PATH="$(yq '.scheduled_tasks.backup.ssh_key_path' $QTOOLS_CONFIG_FILE)"

# Check if any required variable is empty
if [ "$REMOTE_DIR" == "/$NODE_BACKUP_NAME/" ] || [ -z "$REMOTE_URL" ] || [ -z "$REMOTE_USER" ] || [ -z "$SSH_KEY_PATH" ]; then
  echo "Error: One or more required backup settings are missing in the configuration."
  exit 1
fi

# Test SSH connection before proceeding
if ! ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 "$REMOTE_USER@$REMOTE_URL" exit 2>/dev/null; then
  echo "Error: Cannot connect to remote host. Please check your SSH configuration and network connection."
  exit 1
fi

# Attempt to create the remote directory (if it doesn't exist)
ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$REMOTE_USER@$REMOTE_URL" "mkdir -p $REMOTE_DIR" > /dev/null 2>&1 || {
  echo "Warning: Failed to create remote directory. It may already exist or there might be permission issues." >&2
}

echo "Saving store to $REMOTE_DIR"

# Perform the rsync backup for .config directory
if rsync -avzrP --delete-after \
  --exclude="keys.yml" \
  --exclude="config.yml" \
  --exclude="**/snapshot" \
  --info=progress2 \
  -e "ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
  "$CONFIG/" "$REMOTE_USER@$REMOTE_URL:$REMOTE_DIR"; then
  echo "Backup of store directory completed successfully."
else
  echo "Error: Backup of .config directory failed. Please check your rsync command and try again."
  exit 1
fi

echo "All backups completed successfully."

if [ "$RESTART_NODE" == "true" ]; then
  echo "Restarting node"
  qtools start
fi