#/bin/bash
# HELP: Runs a complete install of the node.

sudo apt-get -q update

IS_LINKED="$(yq '.settings.linked_node.enabled' $QTOOLS_CONFIG_FILE)"
DISABLE_SSH_PASSWORDS="$(yq '.settings.install.ssh.disable_password_login') $QTOOLS_CONFIG_FILE"

cd $QUIL_HOME

qtools install-node-binary
qtools install-qclient
qtools update-service

qtools install-go
qtools install-grpc
qtools setup-firewall
qtools install-cron

if [ "$IS_LINKED" != "true" ]; then
    RESTORE_ON_INSTALL="$(yq '.settings.backups.restore_on_install' $QTOOLS_CONFIG_FILE)"
    if [ "$RESTORE_ON_INSTALL" == "true" ]; then
        log "Attempting to restore from remote backup. Note: backups must be enabled and configured properly (and connected to at least once) for this to work."
        qtools restore-backup
    else
        # This first command generates a default config file
        BINARY_NAME="$(get_versioned_node)"
        BINARY_FILE=$QUIL_NODE_PATH/$BINARY_NAME
        $BINARY_FILE -peer-id
        sleep 3
        if [ -f $BINARY_FILE ]; then 
            qtools modify-config
        fi
    fi
fi

# tells server to always start node service on reboot
qtools enable

if [ "$DISABLE_SSH_PASSWORDS" == 'true' ]; then

    PUBLIC_KEY_URL="$(yq '.settings.install.ssh.public_key_url' $QTOOLS_CONFIG_FILE)"
    PUBLIC_KEY="$(yq '.settings.install.ssh.public_key_string' $QTOOLS_CONFIG_FILE)"

    # if defined, fetch remote public key
    if [ ! -z "$PUBLIC_KEY_URL" ]; then
        PUBLIC_KEY="$(dig TXT $PUBLIC_KEY_URL +short | sed -e 's/" "//g' -e 's/"//g')"
    fi

    if [ ! -z "$PUBLIC_KEY" ]; then
        qtools add-public-ssh-key "$PUBLIC_KEY"
    fi

    qtools disable-ssh-passwords
fi

source $QTOOLS_PATH/scripts/install/customization.sh

sudo systemctl reboot
