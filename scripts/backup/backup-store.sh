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
    echo "One or more required backup settings are missing in the configuration."
    exit 1
  fi

  # Check SSH connection
  if ! ssh -i "$SSH_KEY_PATH" -q -o BatchMode=yes -o ConnectTimeout=5 "$REMOTE_USER@$REMOTE_URL" exit &>/dev/null; then
    echo "Error: Unable to establish SSH connection."
    echo "Please check the following:"
    echo "1. SSH key path: $SSH_KEY_PATH"
    echo "2. Remote user: $REMOTE_USER"
    echo "3. Remote URL: $REMOTE_URL"
    echo "4. Ensure the SSH key has correct permissions (chmod 600 $SSH_KEY_PATH)"
    exit 1
  fi

  # Check if the remote directory exists, create if it doesn't
  if ! ssh -i "$SSH_KEY_PATH" "$REMOTE_USER@$REMOTE_URL" "test -d $REMOTE_DIR"; then
    echo "Creating remote directory: $REMOTE_DIR"
    ssh -i "$SSH_KEY_PATH" "$REMOTE_USER@$REMOTE_URL" "mkdir -p $REMOTE_DIR"
  fi

  # Perform the rsync backup
  if rsync -avzrP --delete-after -e "ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no" "$QUIL_NODE_PATH/.config" "$REMOTE_USER@$REMOTE_URL:$REMOTE_DIR"; then
    echo "Backup completed successfully."
  else
    echo "Error: Backup failed. Please check your rsync command and try again."
    exit 1
  fi
else
  log "Backup for $LOCAL_HOSTNAME is not enabled. Modify the qtools config (qtools edit-qtools-config) to enable."
fi