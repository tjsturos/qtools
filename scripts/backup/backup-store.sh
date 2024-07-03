#!/bin/bash
IS_BACKUP_ENABLED="$(yq '.settings.backups.enabled' $QTOOLS_CONFIG_FILE)"
LOCAL_HOSTNAME=$(hostname)

if [ "$IS_BACKUP_ENABLED" == 'true' ]; then
  REMOTE_DIR="$(yq '.settings.backups.remote_backup_dir' $QTOOLS_CONFIG_FILE)/$LOCAL_HOSTNAME/"
  SSH_ALIAS="$(yq '.settings.backups.ssh_alias' $QTOOLS_CONFIG_FILE)"
  log "Backing up $LOCAL_HOSTNAME to remote $SSH_ALIAS:$REMOTE_DIR"

  ssh -q -o BatchMode=yes -o ConnectTimeout=5 $SSH_ALIAS exit

  if [ $? -ne 0 ]; then
    echo "SSH alias $SSH_ALIAS does not exist or is not reachable."
    exit 1
  fi

  ssh $SSH_ALIAS "mkdir -p $REMOTE_DIR"
  rsync -avz --delete -e ssh "$QUIL_NODE_PATH/.config" "$SSH_ALIAS:$REMOTE_DIR"
else
  log "Backup for $LOCAL_HOSTNAME is not enabled. Modify the qtools config to enable."
fi