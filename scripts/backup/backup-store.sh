#!/bin/bash
LOCAL_HOST_NAME=$(hostname)
REMOTE_DIR="/root/backups/$LOCAL_HOST_NAME/"
rsync -avz --ignore-existing --no-delete -e ssh "$QUIL_NODE_PATH/.config" "backup-server:$REMOTE_DIR"