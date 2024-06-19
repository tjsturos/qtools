#/bin/bash

apt-get -q update

IS_LINKED="$(yq '.settings.linked_node.enabled // "false"' $QTOOLS_CONFIG_FILE)"
DISABLE_SSH_PASSWORDS="$(yq '.settings.install.ssh.disable_ssh_login // "false"') $QTOOLS_CONFIG_FILE"

cd $HOME

qtools install-node-binary
qtools install-qclient
qtools update-service

qtools add-auto-complete

qtools install-grpc
qtools setup-firewall
qtools install-cron

# build out the appropriate service(s)
qtools start

# tells server to always start node service on reboot
qtools enable

if [ "$IS_LINKED" != "true" ]; then
    qtools modify-config &
fi

if [ "$DISABLE_SSH_PASSWORDS" == 'true' ]; then
    qtools disable-ssh-passwords
fi

source $QTOOLS_PATH/scripts/install/customization.sh

# log "Installation complete. Going for a reboot."

wait
reboot
