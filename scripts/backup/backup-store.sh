#!/bin/bash
LOCAL_HOST_NAME=$(hostname)
REMOTE_DIR="/root/backups/$LOCAL_HOST_NAME/"
ssh backup-server "mkdir -p $REMOTE_DIR"
rsync -avz --ignore-existing -e ssh "$QUIL_NODE_PATH/.config" "backup-server:$REMOTE_DIR"