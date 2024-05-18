#/bin/bash

apt-get -q update

# make sure git is installed
apt-get install git -y

qtools install-go

export GOROOT=/usr/local/go
export GOPATH=/root/go
export PATH=$GOPATH/bin:$GOROOT/bin:$PATH

# install grpcurl
go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest

cd /root/
git clone https://github.com/QuilibriumNetwork/ceremonyclient.git

# build the 'node' binary
qtools install-node-binary
qtools install qclient-binary

# Copy the service to the systemd directory
cp $QTOOLS_PATH/ceremonyclient.service /lib/systemd/system/

# tells server to always start node service on reboot
systemctl enable ceremonyclient.service

# start the server
systemctl start ceremonyclient.service

qtools restore-backup

log "running customization"
source $QTOOLS_PATH/scripts/install/customization.sh

echo "Installation complete. Going for a reboot."

wait
reboot
