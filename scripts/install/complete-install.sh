#/bin/bash

apt-get -q update

# make sure git is installed
install_package git

qtools install-go
qtools add-auto-complete

cd /root/
git clone $SOURCE_URL

# build the 'node' binary
# qtools install-node-binary
qtools install-qclient-binary
qtools install-grpc
qtools setup-firewall
qtools install-cron

# Copy the service to the systemd directory
cp $QTOOLS_PATH/$QUIL_SERVICE_NAME $SYSTEMD_SERVICE_PATH
cp $QTOOLS_PATH/$QUIL_DEBUG_SERVICE_NAME $SYSTEMD_SERVICE_PATH

qtools update-service

# tells server to always start node service on reboot
qtools enable

# start the server
qtools start

qtools restore-backup &
qtools modify-config &

DISABLE_SSH_PASSWORDS="$(yq e '.settings.ssh.disable_password_login' $QTOOLS_CONFIG_FILE)"
if [ $DISABLE_SSH_PASSWORDS == "true" ]; then
    qtools disable-ssh-passwords
fi

source $QTOOLS_PATH/scripts/install/customization.sh

# log "Installation complete. Going for a reboot."

wait
reboot
