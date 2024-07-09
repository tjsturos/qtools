#/bin/bash
# HELP: Runs a complete install of the node.

sudo apt-get -q update

IS_LINKED="$(yq '.settings.linked_node.enabled' $QTOOLS_CONFIG_FILE)"
DISABLE_SSH_PASSWORDS="$(yq '.settings.install.ssh.disable_ssh_login') $QTOOLS_CONFIG_FILE"

cd $QUIL_HOME

$QTOOLS_PATH/qtools.sh install-node-binary
$QTOOLS_PATH/qtools.sh install-qclient
$QTOOLS_PATH/qtools.sh update-service

$QTOOLS_PATH/qtools.sh install-go
$QTOOLS_PATH/qtools.sh install-grpc
$QTOOLS_PATH/qtools.sh setup-firewall
$QTOOLS_PATH/qtools.sh install-cron

if [ "$IS_LINKED" != "true" ]; then
    # This first command generates a default config file
    BINARY_NAME="$(get_versioned_node)"
    BINARY_FILE=$QUIL_NODE_PATH/$BINARY_NAME
    $BINARY_FILE -peer-id
    sleep 3
    if [ -f $BINARY_FILE ]; then 
        $QTOOLS_PATH/qtools.sh modify-config
    fi
fi

# tells server to always start node service on reboot
$QTOOLS_PATH/qtools.sh enable

if [ "$DISABLE_SSH_PASSWORDS" == 'true' ]; then
    $QTOOLS_PATH/qtools.sh disable-ssh-passwords
fi

source $QTOOLS_PATH/scripts/install/customization.sh

sudo systemctl reboot
