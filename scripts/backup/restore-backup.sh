#!/bin/bash
# HELP: Will restore a backup (if enabled) based on the qtools config settings, otherwise will default to using the peer-id as the backup directory.
# PARAM: --peer-id <string>: the hostname to use when restoring the config directory.
# PARAM: --force: bypass the backup enabled check and force the restore operation.
# Usage: qtools restore-backup # Will default to this machine\'s peer-id as the backup directory.
# Usage: qtools restore-backup --peer-id Qmabcdefg... # Will look for a ~/backups/Qmabcdefg directory on the backup server.
# Usage: qtools restore-backup --force # Will force the restore operation even if backups are disabled.

IS_BACKUP_ENABLED="$(yq '.scheduled_tasks.backup.enabled' $QTOOLS_CONFIG_FILE)"
PEER_ID=""
FORCE_RESTORE=false
CONFIRM=false
OUTPUT_DIR=".config"
STORE=""
EXCLUDE_STORE=""
STATS=""

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --stats)
      STATS=true
      shift
      ;;
    --no-store)
      EXCLUDE_STORE=true
      shift
      ;;
    --store)
      STORE=true
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
    --confirm)
      CONFIRM=true
      shift
      ;;
    --out)
      shift
      OUTPUT_DIR="$1"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

if [ "$IS_BACKUP_ENABLED" == "true" ] || [ "$FORCE_RESTORE" == "true" ]; then

 if [ -z "$PEER_ID" ]; then
    NODE_BACKUP_NAME="$(yq '.scheduled_tasks.backup.node_backup_name' $QTOOLS_CONFIG_FILE)"
  
    # see if there the default save dir is overridden
    if [ -z "$NODE_BACKUP_NAME" ]; then
      PEER_ID="$(qtools peer-id)"
      NODE_BACKUP_NAME="$PEER_ID"
    fi
  else
    NODE_BACKUP_NAME="$PEER_ID"
  fi

  echo "Restoring from $NODE_BACKUP_NAME"

  # Add confirmation prompt if --confirm flag is set
  if [ "$CONFIRM" == "true" ]; then
    read -p "Do you want to continue with the backup to $NODE_BACKUP_NAME? (y/n) " -n 1 -r
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
    echo "One or more required restore settings are missing in the configuration."
    exit 1
  fi

  log "Restoring $LOCAL_HOSTNAME from remote $REMOTE_URL:$REMOTE_DIR"

  ssh -i $SSH_KEY_PATH -q -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 $REMOTE_USER@$REMOTE_URL exit

  if [ $? -ne 0 ]; then
    echo "SSH $REMOTE_URL does not exist or is not reachable or must be connected to initially. Try 'ssh -i $SSH_KEY_PATH $REMOTE_USER@$REMOTE_URL' and accept the fingerprint, then try again."
    exit 1
  fi

  OUTPUT_DIR=".config"
  if [ ! -z "$STORE" ]; then
    OUTPUT_DIR="$OUTPUT_DIR"
    mkdir -p $OUTPUT_DIR
  fi

  # Backup existing .config directory
  if [ -d "$QUIL_NODE_PATH/$OUTPUT_DIR" ]; then
    if [ -d "$QUIL_NODE_PATH/$OUTPUT_DIR.bak" ]; then
      rm -rf $QUIL_NODE_PATH/$OUTPUT_DIR.bak
    fi
    mv $QUIL_NODE_PATH/$OUTPUT_DIR $QUIL_NODE_PATH/$OUTPUT_DIR.bak
  fi

  # Restore .config directory
  if [ "$EXCLUDE_STORE" != "true" ]; then
    rsync -avz --ignore-existing -e "ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" "$REMOTE_USER@$REMOTE_URL:$REMOTE_DIR.config/${STORE:+store/}" "$QUIL_NODE_PATH/$OUTPUT_DIR/}"
  else
    log "Excluding store"
    rsync -avz --ignore-existing --exclude "store" -e "ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" "$REMOTE_USER@$REMOTE_URL:$REMOTE_DIR.config/" "$QUIL_NODE_PATH/$OUTPUT_DIR/"
  fi


  if [ ! -z "$STORE" ] && [ "$STATS" == "true" ]; then
    # Move existing CSV files to .bak if they exist
    for csv_file in "$QTOOLS_PATH"/unclaimed_*_balance.csv; do
      if [ -f "$csv_file" ]; then
        bak_file="${csv_file}.bak"
        if [ -f "$bak_file" ]; then
          rm "$bak_file"
        fi
        mv "$csv_file" "$bak_file"
        echo "Moved $csv_file to $bak_file"
      fi
    done
    
    # Restore CSV files from stats directory to $QTOOLS_PATH
    rsync -avz --ignore-existing \
      --include="unclaimed_*_balance.csv" \
      --exclude="*" \
      -e "ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
      "$REMOTE_USER@$REMOTE_URL:${REMOTE_DIR}stats/" "$QTOOLS_PATH/"
  fi
  log "Restore completed successfully."
else
  log "Restore for $LOCAL_HOSTNAME cannot be done while backups are disabled. Modify the qtools settings.backup config (qtools edit-qtools-config) to enable, or use the --force flag to bypass this check."
fi