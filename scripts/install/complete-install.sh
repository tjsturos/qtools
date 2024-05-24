#/bin/bash

apt-get -q update

# make sure git is installed
install_package git

USER=quilibrium
USER_HOME=$(eval echo "~$USER")
qtools create-authorized-user

qtools install-go
qtools add-auto-complete

export GOROOT=/usr/local/go
export GOPATH=$USER_HOME/go
export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
qtools install-grpc
qtools setup-firewall
qtools setup-cron
qtools disable-ssh-passwords

su - $USER
cd $USER_HOME
git clone https://github.com/QuilibriumNetwork/ceremonyclient.git 

# build the 'node' binary
qtools install-node-binary
qtools install-qclient-binary

# Copy the service to the systemd directory
cp $QTOOLS_PATH/ceremonyclient.service /lib/systemd/system/

# tells server to always start node service on reboot
systemctl enable ceremonyclient.service

# start the server
systemctl start ceremonyclient.service

qtools restore-backup &
qtools modify-config &

source $QTOOLS_PATH/scripts/install/customization.sh

log "Installation complete. Going for a reboot."

wait
reboot
