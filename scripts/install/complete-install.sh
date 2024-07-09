#/bin/bash
# HELP: Runs a complete install of the node.

sudo apt-get -q update

IS_LINKED="$(yq '.settings.linked_node.enabled' $QTOOLS_CONFIG_FILE)"
DISABLE_SSH_PASSWORDS="$(yq '.settings.install.ssh.disable_ssh_login') $QTOOLS_CONFIG_FILE"

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
    qtools disable-ssh-passwords
fi

source $QTOOLS_PATH/scripts/install/customization.sh

sudo systemctl reboot
