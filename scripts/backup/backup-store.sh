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

  ssh -i $SSH_KEY_PATH -q -o BatchMode=yes -o ConnectTimeout=5 $REMOTE_USER@$REMOTE_URL exit

  if [ $? -ne 0 ]; then
    echo "SSH alias $SSH_KEY_PATH $REMOTE_USER@$REMOTE_URL does not exist or is not reachable."
    exit 1
  fi

  # Check if the remote directory does not exist before creating it
  ssh -i $SSH_KEY_PATH $REMOTE_USER@$REMOTE_URL "test -d $REMOTE_DIR || mkdir -p $REMOTE_DIR"

  rsync -avzrP --delete-after -e "ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no" "$QUIL_NODE_PATH/.config" "$REMOTE_USER@$REMOTE_URL:$REMOTE_DIR"
else
  log "Backup for $LOCAL_HOSTNAME is not enabled. Modify the qtools config (qtools edit-qtools-config) to enable."
fi
