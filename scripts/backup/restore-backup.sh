#!/bin/bash
# HELP: Will restore a backup (if enabled) based on the qtools config settings, otherwise will look for a backup directory with this node's hostname.
# PARAM: --hostname <string>: the hostname to use when restoring the config directory.
# Usage: qtools restore-backup # Will default to this machine's hostname if not defined in the qtools/config.yml
# Usage: qtools restore-backup --hostname quil-miner-101 # Will look for a ~/backups/quil-miner-101 directory on the backup server.

IS_BACKUP_ENABLED="$(yq '.settings.backups.enabled' $QTOOLS_CONFIG_FILE)"
LOCAL_HOSTNAME=$(hostname)

if [ "$IS_BACKUP_ENABLED" == 'true' ]; then
  NODE_BACKUP_DIR="$(yq '.settings.backups.node_backup_dir' $QTOOLS_CONFIG_FILE)"
  if [ "$1" == "--hostname" ]; then
    shift
    NODE_BACKUP_DIR="$1"
  else
    # see if there the default save dir is overridden
    if [ -z "$NODE_BACKUP_DIR" ]; then
    
      NODE_BACKUP_DIR="$LOCAL_HOSTNAME"
    fi
  fi

  REMOTE_DIR="$(yq '.settings.backups.remote_backup_dir' $QTOOLS_CONFIG_FILE)/$NODE_BACKUP_DIR/"
  SSH_ALIAS="$(yq '.settings.backups.ssh_alias' $QTOOLS_CONFIG_FILE)"
  REMOTE_URL="$(yq '.settings.backups.backup_url' $QTOOLS_CONFIG_FILE)"
  REMOTE_USER="$(yq '.settings.backups.remote_user' $QTOOLS_CONFIG_FILE)"
  SSH_KEY_PATH="$(yq '.settings.backups.ssh_key_path' $QTOOLS_CONFIG_FILE)"

  # Check if any required variable is empty
  if [ "$REMOTE_DIR" == "/$NODE_BACKUP_DIR/" ] || [ -z "$SSH_ALIAS" ] || [ -z "$REMOTE_URL" ] || [ -z "$REMOTE_USER" ] || [ -z "$SSH_KEY_PATH" ]; then
    echo "One or more required restore settings are missing in the configuration."
    exit 1
  fi

  log "Restoring $LOCAL_HOSTNAME from remote $SSH_ALIAS:$REMOTE_DIR"

  ssh -i $SSH_KEY_PATH -q -o BatchMode=yes -o ConnectTimeout=5 $REMOTE_USER@$REMOTE_URL exit

  if [ $? -ne 0 ]; then
    echo "SSH alias $SSH_ALIAS does not exist or is not reachable."
    exit 1
  fi

  rsync -avz --ignore-existing -e "ssh -i $SSH_KEY_PATH" "$REMOTE_USER@$REMOTE_URL:$REMOTE_DIR" "$QUIL_NODE_PATH/"
else
  log "Restore for $LOCAL_HOSTNAME cannot be done while backups are disabled. Modify the qtools settings.backup config (qtools edit-qtools-config) to enable."
fi