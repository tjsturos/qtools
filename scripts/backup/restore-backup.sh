#!/bin/bash
# HELP: Will restore a backup (if enabled) based on the qtools config settings, otherwise will look for a backup directory with this node's hostname.
# PARAM: --peer-id <string>: the hostname to use when restoring the config directory.
# PARAM: --force: bypass the backup enabled check and force the restore operation.
# Usage: qtools restore-backup # Will default to this machine's hostname if not defined in the qtools/config.yml
# Usage: qtools restore-backup --peer-id Qmabcdefg... # Will look for a ~/backups/Qmabcdefg directory on the backup server.
# Usage: qtools restore-backup --force # Will force the restore operation even if backups are disabled.

IS_BACKUP_ENABLED="$(yq '.settings.backups.enabled' $QTOOLS_CONFIG_FILE)"
PEER_ID=""
FORCE_RESTORE=false
CONFIRM=false

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --force)
      FORCE_RESTORE=true
      shift
      ;;
    --peer-id)
      shift
      PEER_ID="$1"
      shift
      ;;
    --confirm)
      CONFIRM=true
      shift
      ;;
    *)
      shift
      ;;
  esac
done

if [ "$IS_BACKUP_ENABLED" == 'true' ] || [ "$FORCE_RESTORE" == true ]; then

 if [ -z "$PEER_ID" ]; then
    NODE_BACKUP_DIR="$(yq '.settings.backups.node_backup_dir' $QTOOLS_CONFIG_FILE)"
  
    # see if there the default save dir is overridden
    if [ -z "$NODE_BACKUP_DIR" ]; then
      PEER_ID="$(qtools peer-id)"
      NODE_BACKUP_DIR="$PEER_ID"
    fi
  else
    NODE_BACKUP_DIR="$PEER_ID"
  fi

  echo "Restoring from $NODE_BACKUP_DIR"

  # Add confirmation prompt if --confirm flag is set
  if [ "$CONFIRM" = true ]; then
    read -p "Do you want to continue with the backup to $NODE_BACKUP_DIR? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Backup cancelled."
      exit 0
    fi
  fi
  
  REMOTE_DIR="$(yq '.settings.backups.remote_backup_dir' $QTOOLS_CONFIG_FILE)/$NODE_BACKUP_DIR/"
  REMOTE_URL="$(yq '.settings.backups.backup_url' $QTOOLS_CONFIG_FILE)"
  REMOTE_USER="$(yq '.settings.backups.remote_user' $QTOOLS_CONFIG_FILE)"
  SSH_KEY_PATH="$(yq '.settings.backups.ssh_key_path' $QTOOLS_CONFIG_FILE)"

  # Check if any required variable is empty
  if [ "$REMOTE_DIR" == "/$NODE_BACKUP_DIR/" ] || [ -z "$REMOTE_URL" ] || [ -z "$REMOTE_USER" ] || [ -z "$SSH_KEY_PATH" ]; then
    echo "One or more required restore settings are missing in the configuration."
    exit 1
  fi

  log "Restoring $LOCAL_HOSTNAME from remote $REMOTE_URL:$REMOTE_DIR"

  ssh -i $SSH_KEY_PATH -q -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 $REMOTE_USER@$REMOTE_URL exit

  if [ $? -ne 0 ]; then
    echo "SSH $REMOTE_URL does not exist or is not reachable or must be connected to initially. Try 'ssh -i $SSH_KEY_PATH $REMOTE_USER@$REMOTE_URL' and accept the fingerprint, then try again."
    exit 1
  fi

  # Backup existing .config directory
  if [ -d "$QUIL_NODE_PATH/.config" ]; then
    if [ -d "$QUIL_NODE_PATH/.config.bak" ]; then
      rm -rf $QUIL_NODE_PATH/.config.bak
    fi
    mv $QUIL_NODE_PATH/.config $QUIL_NODE_PATH/.config.bak
  fi

  # Restore .config directory
  rsync -avz --ignore-existing -e "ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" "$REMOTE_USER@$REMOTE_URL:$REMOTE_DIR.config" "$QUIL_NODE_PATH/"

  # Restore CSV files from stats directory to $QTOOLS_PATH
  rsync -avz --ignore-existing \
    --include="unclaimed_*_balance.csv" \
    --exclude="*" \
    -e "ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
    "$REMOTE_USER@$REMOTE_URL:${REMOTE_DIR}stats/" "$QTOOLS_PATH/"

  log "Restore completed successfully."
else
  log "Restore for $LOCAL_HOSTNAME cannot be done while backups are disabled. Modify the qtools settings.backup config (qtools edit-qtools-config) to enable, or use the --force flag to bypass this check."
fi