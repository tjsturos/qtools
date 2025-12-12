#!/bin/bash
# HELP: Backs up peer config files (keys.yml and config.yml) to remote location.
# PARAM: --confirm: prompts for confirmation before proceeding with the backup
# PARAM: --peer-id <string>: the peer-id to use when backing up the config directory.
# PARAM: --force: bypass the backup enabled check and force the backup operation.
# Usage: qtools backup-peer [--confirm]

IS_BACKUP_ENABLED="$(yq '.scheduled_tasks.backup.enabled // false' $QTOOLS_CONFIG_FILE)"
CONFIRM=false
AUTO=false
LOCAL=""
# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --auto)
      AUTO=true
      shift
      ;;
    --confirm)
      CONFIRM=true
      shift
      ;;
    --local)
      if [ -z "$2" ]; then
        echo "Error: --local flag requires a directory path, e.g. qtools backup-peer --local /path/to/backup"
        exit 1
      fi
      LOCAL=$2
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

if [ ! -z "$LOCAL" ]; then
  # Create local directory if it doesn't exist
  mkdir -p "$LOCAL"
  echo "Backing up peer config from local directory: $LOCAL"

  cp $QUIL_NODE_PATH/.config/config.yml $LOCAL/config.yml
  cp $QUIL_NODE_PATH/.config/keys.yml $LOCAL/keys.yml

  echo "Peer config backup completed successfully."
  exit 0
fi

PEER_ID="$1"

if [ -z "$PEER_ID" ]; then
  NODE_BACKUP_NAME="$(yq '.scheduled_tasks.backup.node_backup_name' $QTOOLS_CONFIG_FILE)"

  # see if there the default save dir is overridden
  if [ -z "$NODE_BACKUP_NAME" ]; then
    PEER_ID="$(qtools --describe "backup-peer" peer-id)"
    NODE_BACKUP_NAME="$PEER_ID"
  fi
else
  NODE_BACKUP_NAME="$PEER_ID"
fi

# Check if NODE_BACKUP_NAME starts with "Qm"
if [[ ! "$NODE_BACKUP_NAME" =~ ^Qm ]]; then
  echo "Error: Invalid backup name '$NODE_BACKUP_NAME'. Backup name must start with 'Qm'."
  exit 1
fi

echo "Backing up peer config to $NODE_BACKUP_NAME"

# Add confirmation prompt if --confirm flag is set
if [ "$CONFIRM" == "true" ]; then
  read -p "Do you want to continue with the peer config backup to $NODE_BACKUP_NAME? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Backup cancelled."
    exit 0
  fi
fi

REMOTE_DIR="$(yq '.scheduled_tasks.backup.remote_backup_dir' $QTOOLS_CONFIG_FILE)/$NODE_BACKUP_NAME/"
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
ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$REMOTE_USER@$REMOTE_URL" "mkdir -p $REMOTE_DIR/.config" > /dev/null 2>&1 || {
  echo "Warning: Failed to create remote directory. It may already exist or there might be permission issues." >&2
}

cp $QTOOLS_PATH/config.yml $QUIL_NODE_PATH/.config/qtools-config.yml


# Perform the rsync backup for specific config files
if rsync -avzrP --delete-after \
  --include="keys.yml" \
  --include="config.yml" \
  --include="qtools-config.yml" \
  --exclude="*" \
  -e "ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
  "$QUIL_NODE_PATH/.config/" "$REMOTE_USER@$REMOTE_URL:$REMOTE_DIR/.config/"; then
  echo "Backup of peer config files completed successfully."
else
  echo "Error: Backup of peer config files failed. Please check your rsync command and try again."
  exit 1
fi

echo "Peer config backup completed successfully."

