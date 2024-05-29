#/bin/bash

apt-get -q update

# make sure git is installed
install_package git

qtools install-go
qtools add-auto-complete

export GOROOT=/usr/local/go
export GOPATH=/root/go
export PATH=$GOPATH/bin:$GOROOT/bin:$PATH

cd /root/
git clone https://github.com/QuilibriumNetwork/ceremonyclient.git

# build the 'node' binary
qtools install-node-binary
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
qtools disable-ssh-passwords

source $QTOOLS_PATH/scripts/install/customization.sh

log "Installation complete. Going for a reboot."

wait
reboot
