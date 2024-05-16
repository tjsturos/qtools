#/bin/bash

# Setup the cron for reboots
source ./scripts/setup-cron.sh

apt-get -q update

# make sure git is installed
apt-get install git -y

source ./scripts/install-go.sh

BASHRC=~/.bashrc
append_to_file $BASHRC "GOROOT=/usr/local/go"
append_to_file $BASHRC "GOPATH=$HOME/go"
append_to_file $BASHRC "PATH=\$GOPATH/bin:\$GOROOT/bin:\$PATH"

GOROOT=/usr/local/go
GOPATH=/root/go
PATH=$GOPATH/bin:$GOROOT/bin:$PATH

echo "$PATH" > ~/saved-path

FILE_SYSCTL=/etc/sysctl.conf

# make sure bandwidth is optimized 
append_to_file $FILE_SYSCTL "net.core.rmem_max = 600000000"
append_to_file $FILE_SYSCTL "net.core.wmem_max = 600000000"
# load the updates
sysctl -p

log "setting up firewall"
echo "y" | ufw enable
ufw allow 22
ufw allow 8336
ufw allow 443

cd $HOME && git clone https://github.com/QuilibriumNetwork/ceremonyclient.git

# build the Node binary
cd $HOME/ceremonyclient/node
log "The current directory is $(pwd), path is $PATH"
GOEXPERIMENT=arenas go install  ./... >> $CURRENT_DIR/$FILE_LOG

# Copy the service to the systemd directory
cp $CURRENT_DIR/ceremonyclient.service /lib/systemd/system/

# tells server to start on reboot
systemctl enable ceremonyclient.service
# make sure to indicate we are done with phase one (needing a reboot)
touch $FLAG_AFTER_FIRST_REBOOT
echo "$CURRENT_DIR" > $FLAG_AFTER_FIRST_REBOOT

echo "First installion segment done. Going for a reboot. Installation will automatically continue on reboot."
reboot
