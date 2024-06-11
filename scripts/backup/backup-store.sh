#!/bin/bash
LOCAL_HOST_NAME=$(hostname)
REMOTE_DIR="/root/backups/$LOCAL_HOST_NAME/"
SSH_ALIAS="backup-server"

ssh -q -o BatchMode=yes -o ConnectTimeout=5 $SSH_ALIAS exit

if [ $? -ne 0 ]; then
  echo "SSH alias $SSH_ALIAS does not exist or is not reachable."
  exit 1
fi

ssh $SSH_ALIAS "mkdir -p $REMOTE_DIR"
rsync -avz --ignore-existing -e ssh "$QUIL_NODE_PATH/.config" "$SSH_ALIAS:$REMOTE_DIR"