#!/bin/bash
IS_BACKUP_ENABLED="$(yq '.settings.backups.enabled' $QTOOLS_CONFIG_FILE)"

if [ "$IS_BACKUP_ENABLED" == 'true' ]; then
    NODE_BACKUP_DIR="$(yq '.settings.backups.node_backup_dir' $QTOOLS_CONFIG_FILE)"
    # see if there the default save dir is overriden
    if [ -z "$NODE_BACKUP_DIR" ]; then
        NODE_BACKUP_DIR="$(hostname)"
    fi
    LOCAL_PATH="$QUIL_PATH/app/.config"
    REMOTE_PATH="~/backups/$NODE_BACKUP_DIR/.config"
    SSH_ALIAS="$(yq '.settings.backups.ssh_alias' $QTOOLS_CONFIG_FILE)"
    REMOTE_URL="$(yq '.settings.backups.backup_url' $QTOOLS_CONFIG_FILE)"
    REMOTE_USER="$(yq '.settings.backups.remote_user' $QTOOLS_CONFIG_FILE)"
    SSH_KEY_PATH="$(yq '.settings.backups.ssh_key_path' $QTOOLS_CONFIG_FILE)"

    ssh -i $SSH_KEY_PATH -q -o BatchMode=yes -o ConnectTimeout=5 $REMOTE_USER@$REMOTE_URL exit

    if [ $? -ne 0 ]; then
        echo "SSH alias $SSH_ALIAS does not exist or is not reachable."
        exit 1
    fi

    # Get lists of files and their sizes
    local_files=$(find "$LOCAL_PATH" -type f -exec stat -c "%n %s" {} \;)
    remote_files=$(ssh -i $SSH_KEY_PATH $REMOTE_USER@$REMOTE_URL "find $REMOTE_PATH -type f -exec stat -c \"%n %s\" {} \;")

    # Function to check if a file exists in remote files
    function file_exists_in_remote {
        local file=$1
        local size=$2

        while IFS= read -r remote_file; do
            remote_file_path=$(echo "$remote_file" | awk '{print $1}')
            remote_file_size=$(echo "$remote_file" | awk '{print $2}')
            remote_file_relative=$(echo "$remote_file_path" | sed "s|$REMOTE_PATH||")

            if [ "$file" == "$remote_file_relative" ] && [ "$size" == "$remote_file_size" ]; then
                return 0
            fi
        done <<< "$remote_files"

        return 1
    }

    # Check local files against remote
    while IFS= read -r local_file; do
        local_file_path=$(echo "$local_file" | awk '{print $1}')
        local_file_size=$(echo "$local_file" | awk '{print $2}')
        local_file_relative=$(echo "$local_file_path" | sed "s|$LOCAL_PATH||")

        if ! file_exists_in_remote "$local_file_relative" "$local_file_size"; then
            echo "File $local_file_relative is missing or size mismatch in remote backup."
            exit 1
        fi
    done <<< "$local_files"

    # Check remote files against local (to ensure no old files exist)
    while IFS= read -r remote_file; do
        remote_file_path=$(echo "$remote_file" | awk '{print $1}')
        remote_file_relative=$(echo "$remote_file_path" | sed "s|$REMOTE_PATH||")

        if ! grep -q "$remote_file_relative" <<< "$local_files"; then
            echo "Old file $remote_file_relative exists in remote backup but not locally."
            exit 1
        fi
    done <<< "$remote_files"

    echo "All files are correctly backed up and no old files exist in the remote backup."
fi