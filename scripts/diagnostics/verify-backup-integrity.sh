#!/bin/bash
IS_BACKUP_ENABLED="$(yq '.scheduled_tasks.backup.enabled' $QTOOLS_CONFIG_FILE)"

if [ "$IS_BACKUP_ENABLED" == 'true' ]; then
    qtools --describe "verify-backup-integrity" backup-store
    wait
    NODE_BACKUP_NAME="$(yq '.scheduled_tasks.backup.node_backup_name' $QTOOLS_CONFIG_FILE)"
    # see if there the default save dir is overriden
    if [ -z "$NODE_BACKUP_NAME" ]; then
        NODE_BACKUP_NAME="$(qtools --describe "verify-backup-integrity" peer-id)"
    fi
    LOCAL_PATH="$QUIL_PATH/node/.config"
    REMOTE_DIR="$(yq '.scheduled_tasks.backup.remote_backup_dir' $QTOOLS_CONFIG_FILE)"
    REMOTE_PATH="$REMOTE_DIR/$NODE_BACKUP_NAME/.config"
    REMOTE_URL="$(yq '.scheduled_tasks.backup.backup_url' $QTOOLS_CONFIG_FILE)"
    REMOTE_USER="$(yq '.scheduled_tasks.backup.remote_user' $QTOOLS_CONFIG_FILE)"
    SSH_KEY_PATH="$(yq '.scheduled_tasks.backup.ssh_key_path' $QTOOLS_CONFIG_FILE)"

    # Check if any required variable is empty
    if [ "$REMOTE_DIR" == "/$NODE_BACKUP_NAME/" ] || [ -z "$REMOTE_URL" ] || [ -z "$REMOTE_USER" ] || [ -z "$SSH_KEY_PATH" ]; then
        echo "One or more required backup settings are missing in the configuration."
        exit 1
    fi

    ssh -i $SSH_KEY_PATH -q -o BatchMode=yes -o ConnectTimeout=5 $REMOTE_USER@$REMOTE_URL exit

    if [ $? -ne 0 ]; then
        echo "SSH alias $REMOTE_USER@$REMOTE_URL or $SSH_KEY_PATH does not exist or is not reachable."
        exit 1
    fi

    # Get lists of files and their sizes
    local_files=$(find "$LOCAL_PATH" -type f -exec stat -c "%n %s" {} \;)
    remote_files=$(ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $REMOTE_USER@$REMOTE_URL "find $REMOTE_PATH -type f -exec stat -c \"%n %s\" {} \;")

    # Function to check if a file exists in remote files
    function file_exists_in_remote {
        local file=$1
        local size=$2

        while IFS= read -r remote_file; do
            remote_file_name=$(echo "$remote_file" | awk '{print $1}' | xargs basename)
            remote_file_size=$(echo "$remote_file" | awk '{print $2}')

            if [ "$file" == "$remote_file_name" ] && [ "$size" == "$remote_file_size" ]; then
                return 0
            fi
        done <<< "$remote_files"

        return 1
    }

    # Check local files against remote
    while IFS= read -r local_file; do
        local_file_name=$(echo "$local_file" | awk '{print $1}' | xargs basename)
        local_file_size=$(echo "$local_file" | awk '{print $2}')

        if ! file_exists_in_remote "$local_file_name" "$local_file_size"; then
            echo "File $local_file_name is missing or size mismatch in remote backup."
            exit 1
        fi
    done <<< "$local_files"

    # Check remote files against local (to ensure no old files exist)
    function file_exists_in_local {
        local file=$1

        while IFS= read -r local_file; do
            local_file_name=$(echo "$local_file" | awk '{print $1}' | xargs basename)

            if [ "$file" == "$local_file_name" ]; then
                return 0
            fi
        done <<< "$local_files"

        return 1
    }

    while IFS= read -r remote_file; do
        remote_file_name=$(echo "$remote_file" | awk '{print $1}' | xargs basename)

        if ! file_exists_in_local "$remote_file_name"; then
            echo "Old file $remote_file_name exists in remote backup but not locally."
            exit 1
        fi
    done <<< "$remote_files"

    echo "All files are correctly backed up and no old files exist in the remote backup."
    return 0
fi

