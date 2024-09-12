#!/bin/bash
# HELP: Backs up store (if enabled in qtools config) to remote location.
# PARAM: --confirm: prompts for confirmation before proceeding with the backup
# Usage: qtools backup-store [--confirm]


IS_BACKUP_ENABLED="$(yq '.settings.backups.enabled' $QTOOLS_CONFIG_FILE)"
CONFIRM=false
PEER_ID=""
FORCE_RESTORE=false

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --confirm) 
      CONFIRM=true 
      shift
      ;;
    --force)
      FORCE_RESTORE=true
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

  echo "Backing up to $NODE_BACKUP_DIR"

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
    echo "Error: One or more required backup settings are missing in the configuration."
    exit 1
  fi

  # Attempt to create the remote directory (if it doesn't exist)
  ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$REMOTE_USER@$REMOTE_URL" "mkdir -p $REMOTE_DIR" > /dev/null 2>&1 || {
    echo "Warning: Failed to create remote directory. It may already exist or there might be permission issues." >&2
  }

  # Perform the rsync backup for .config directory
  if rsync -avzrP --delete-after -e "ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" "$QUIL_NODE_PATH/.config" "$REMOTE_USER@$REMOTE_URL:$REMOTE_DIR"; then
    echo "Backup of .config directory completed successfully."
  else
    echo "Error: Backup of .config directory failed. Please check your rsync command and try again."
    exit 1
  fi

  # Create the stats directory if it doesn't exist
  ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$REMOTE_USER@$REMOTE_URL" "mkdir -p ${REMOTE_DIR}stats"
  
  # Backup qtools/unclaimed_*_balance.csv files to stats directory
  if rsync -avzrP --delete-after \
    --include="unclaimed_*_balance.csv" \
    --exclude="*" \
    -e "ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
    "$QTOOLS_PATH/" "$REMOTE_USER@$REMOTE_URL:${REMOTE_DIR}stats/"; then
    echo "Backup of unclaimed balance files completed successfully."
  else
    echo "Error: Backup of unclaimed balance files failed. Please check your rsync command and try again."
    exit 1
  fi

  echo "All backups completed successfully."
else
  log "Backup for $LOCAL_HOSTNAME is not enabled. Modify the qtools config (qtools edit-qtools-config) to enable."
fi