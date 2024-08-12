#!/bin/bash
# HELP: Backs up store (if enabled in qtools config) to remote location.

IS_BACKUP_ENABLED="$(yq '.settings.backups.enabled' $QTOOLS_CONFIG_FILE)"
LOCAL_HOSTNAME=$(hostname)

if [ "$IS_BACKUP_ENABLED" == 'true' ]; then
  NODE_BACKUP_DIR="$(yq '.settings.backups.node_backup_dir' $QTOOLS_CONFIG_FILE)"
  # see if there the default save dir is overriden
  if [ -z "$NODE_BACKUP_DIR" ]; then
    NODE_BACKUP_DIR="$LOCAL_HOSTNAME"
  fi
  REMOTE_DIR="$(yq '.settings.backups.remote_backup_dir' $QTOOLS_CONFIG_FILE)/$NODE_BACKUP_DIR/"
  REMOTE_URL="$(yq '.settings.backups.backup_url' $QTOOLS_CONFIG_FILE)"
  REMOTE_USER="$(yq '.settings.backups.remote_user' $QTOOLS_CONFIG_FILE)"
  SSH_KEY_PATH="$(yq '.settings.backups.ssh_key_path' $QTOOLS_CONFIG_FILE)"

  # Check if any required variable is empty
  if [ "$REMOTE_DIR" == "/$NODE_BACKUP_DIR/" ] || [ -z "$REMOTE_URL" ] || [ -z "$REMOTE_USER" ] || [ -z "$SSH_KEY_PATH" ]; then
    echo "Error: One or more required backup settings are missing in the configuration."
    exit 1
  fi

  # Attempt to create the remote directory (if it doesn't exist)
  ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$REMOTE_USER@$REMOTE_URL" "mkdir -p $REMOTE_DIR" || {
    echo "Warning: Failed to create remote directory. It may already exist or there might be permission issues."
  }

  # Perform the rsync backup for .config directory
  if rsync -avzrP --delete-after -e "ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" "$QUIL_NODE_PATH/.config" "$REMOTE_USER@$REMOTE_URL:$REMOTE_DIR"; then
    echo "Backup of .config directory completed successfully."
  else
    echo "Error: Backup of .config directory failed. Please check your rsync command and try again."
    exit 1
  fi

  # Backup qtools/unclaimed_*_balance.csv files to stats directory
  if rsync -avzrP --delete-after -e "ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" "$QTOOLS_PATH/unclaimed_*_balance.csv" "$REMOTE_USER@$REMOTE_URL:$REMOTE_DIR/stats/"; then
    echo "Backup of unclaimed balance files completed successfully."
  else
    echo "Error: Backup of unclaimed balance files failed. Please check your rsync command and try again."
    exit 1
  fi

  echo "All backups completed successfully."
else
  log "Backup for $LOCAL_HOSTNAME is not enabled. Modify the qtools config (qtools edit-qtools-config) to enable."
fi