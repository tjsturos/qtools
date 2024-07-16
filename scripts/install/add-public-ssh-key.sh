#!/bin/bash

PUBLIC_KEY="$1"

AUTHORIZED_KEYS_FILE=$HOME/.ssh/authorized_keys

# Create .ssh directory and authorized_keys file if they don't exist
mkdir -p $HOME/.ssh
touch $AUTHORIZED_KEYS_FILE

# Append the key to authorized_keys if not already present
if ! grep -q "$PUBLIC_KEY" $AUTHORIZED_KEYS_FILE; then
    echo "$PUBLIC_KEY" >> $AUTHORIZED_KEYS_FILE
fi

# Set appropriate permissionsthen
sudo chmod 600 $AUTHORIZED_KEYS_FILE
sudo chown $USER:$USER $AUTHORIZED_KEYS_FILE
