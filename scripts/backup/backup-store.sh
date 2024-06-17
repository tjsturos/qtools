#!/bin/bash
IS_BACKUP_ENABLED="$(yq e '.settings.backup.enabled)' $QTOOLS_CONFIG_FILE)"

if [ $IS_BACKUP_ENABLED == 'true' ]; then
  LOCAL_HOST_NAME=$(hostname)
  REMOTE_DIR="$(yq e '.settings.backup.remote_backup_dir' $QTOOLS_CONFIG_FILE)/$LOCAL_HOST_NAME/"
  SSH_ALIAS="$(yq e '.settings.backup.ssh_alias' $QTOOLS_CONFIG_FILE)"

  ssh -q -o BatchMode=yes -o ConnectTimeout=5 $SSH_ALIAS exit

  if [ $? -ne 0 ]; then
    echo "SSH alias $SSH_ALIAS does not exist or is not reachable."
    exit 1
  fi

  ssh $SSH_ALIAS "mkdir -p $REMOTE_DIR"
  rsync -avz --ignore-existing -e ssh "$QUIL_NODE_PATH/.config" "$SSH_ALIAS:$REMOTE_DIR"
fi