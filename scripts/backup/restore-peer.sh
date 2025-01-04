#!/bin/bash
# HELP: Restores peer config files (keys.yml and config.yml) from remote location.
# PARAM: --confirm: prompts for confirmation before proceeding with the restore
# PARAM: --peer-id <string>: the peer-id to use when restoring the config directory.
# PARAM: --force: bypass the backup enabled check and force the restore operation.
# Usage: qtools restore-peer [--confirm]

IS_BACKUP_ENABLED="$(yq '.scheduled_tasks.backup.enabled // false' $QTOOLS_CONFIG_FILE)"

AUTO=false
LOCAL=""
# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --auto)
      AUTO=true
      shift
      ;;
    --local)
      LOCAL=$2
      shift
      shift
      ;;
    *)
      if [[ "$1" =~ ^Qm ]]; then
        PEER_ID="$1"
      fi
      shift
      ;;
  esac
done

if [ ! -z "$LOCAL" ]; then
    if [ ! -d "$LOCAL" ]; then
        echo "Error: Local directory '$LOCAL' does not exist"
        exit 1
    fi

    # Check for required config files in local directory
    if [ ! -f "$LOCAL/config.yml" ] || [ ! -f "$LOCAL/keys.yml" ]; then
        echo "Error: Required config files not found in $LOCAL"
        exit 1
    fi
    echo "Restoring peer config from local directory: $LOCAL"
    # Get encryption key and peer private key from local config
    ENCRYPTION_KEY="$(yq '.key.keyManagerFile.encryptionKey' "$LOCAL/config.yml")"
    PEER_PRIVATE_KEY="$(yq '.p2p.peerPrivKey' "$LOCAL/config.yml")"

    # Create .config directory if it doesn't exist
    mkdir -p "$QUIL_NODE_PATH/.config"
    echo "Getting encryption key from local config"
    yq -i ".key.keyManagerFile.encryptionKey = \"$ENCRYPTION_KEY\"" $QUIL_NODE_PATH/.config/config.yml
    echo "Getting peer private key from local config"
    yq -i ".p2p.peerPrivKey = \"$PEER_PRIVATE_KEY\"" $QUIL_NODE_PATH/.config/config.yml
    echo "Copying keys.yml from local config"
    cp $LOCAL/keys.yml $QUIL_NODE_PATH/.config/keys.yml
    
    echo "Restored peer config from local directory: $LOCAL"
    exit 0
fi


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

# Check if NODE_BACKUP_NAME starts with "Qm"
if [[ ! "$NODE_BACKUP_NAME" =~ ^Qm ]]; then
    echo "Error: Invalid backup name '$NODE_BACKUP_NAME'. Backup name must start with 'Qm'."
    exit 1
fi

echo "Restoring peer config from $NODE_BACKUP_NAME"


REMOTE_DIR="$(yq '.scheduled_tasks.backup.remote_backup_dir' $QTOOLS_CONFIG_FILE)/$NODE_BACKUP_NAME/"
REMOTE_URL="$(yq '.scheduled_tasks.backup.backup_url' $QTOOLS_CONFIG_FILE)"
REMOTE_USER="$(yq '.scheduled_tasks.backup.remote_user' $QTOOLS_CONFIG_FILE)"
SSH_KEY_PATH="$(yq '.scheduled_tasks.backup.ssh_key_path' $QTOOLS_CONFIG_FILE)"

# Check if any required variable is empty
if [ "$REMOTE_DIR" == "/$NODE_BACKUP_NAME/" ] || [ -z "$REMOTE_URL" ] || [ -z "$REMOTE_USER" ] || [ -z "$SSH_KEY_PATH" ]; then
    echo "Error: One or more required restore settings are missing in the configuration."
    exit 1
fi

# Test SSH connection before proceeding
if ! ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 "$REMOTE_USER@$REMOTE_URL" exit 2>/dev/null; then
  echo "Error: Cannot connect to remote host. Please check your SSH configuration and network connection."
  exit 1
fi

# Create .config directory if it doesn't exist
mkdir -p "$QUIL_NODE_PATH/.config"

REMOTE_KEY_ENCRYPTION_KEY_COMMAND="yq '.key.keyManagerFile.encryptionKey' ${REMOTE_DIR}.config/config.yml"
PEER_PRIVATE_KEY_COMMAND="yq '.p2p.peerPrivKey' ${REMOTE_DIR}.config/config.yml"
ENCRYPTION_KEY="$(ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 "$REMOTE_USER@$REMOTE_URL" "$REMOTE_KEY_ENCRYPTION_KEY_COMMAND")"
PEER_PRIVATE_KEY="$(ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 "$REMOTE_USER@$REMOTE_URL" "$PEER_PRIVATE_KEY_COMMAND")"
# Perform the rsync restore for specific config files
if rsync -avz \
    --include="keys.yml" \
    --exclude="*" \
    -e "ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
    "$REMOTE_USER@$REMOTE_URL:$REMOTE_DIR.config/" "$QUIL_NODE_PATH/.config/"; then
    yq -i ".key.keyManagerFile.encryptionKey = \"$ENCRYPTION_KEY\"" $QUIL_NODE_PATH/.config/config.yml
    yq -i ".p2p.peerPrivKey = \"$PEER_PRIVATE_KEY\"" $QUIL_NODE_PATH/.config/config.yml

    echo "Restore of peer config files completed successfully."
else
    echo "Error: Restore of peer config files failed. Please check your rsync command and try again."
    exit 1
fi

echo "Peer config restore completed successfully."

