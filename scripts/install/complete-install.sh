#/bin/bash

apt-get -q update

INSTALL_METHOD="$(yq '.settings.install.method' $QTOOLS_CONFIG_FILE)"
IS_LINKED="$(yq '.settings.linked_node.enabled' $QTOOLS_CONFIG_FILE)"
DISABLE_SSH_PASSWORDS="$(yq '.settings.install.ssh.disable_ssh_login') $QTOOLS_CONFIG_FILE"

cd $HOME

source $QTOOLS_PATH/scripts/install/install-from-release.sh

qtools add-auto-complete

qtools install-grpc
qtools setup-firewall
qtools install-cron

# build out the appropriate service(s)
qtools update-service
qtools start

# tells server to always start node service on reboot
qtools enable

if [ "$IS_LINKED" != "true" ]; then
    qtools modify-config &
fi

if [ $DISABLE_SSH_PASSWORDS == 'true' ]; then
    qtools disable-ssh-passwords
fi

source $QTOOLS_PATH/scripts/install/customization.sh

# log "Installation complete. Going for a reboot."

wait
reboot
