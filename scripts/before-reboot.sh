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

source $BASHRC

echo "$PATH" > ~/saved-path

FILE_SYSCTL=/etc/sysctl.conf

# make sure bandwidth is optimized 
append_to_file $FILE_SYSCTL "net.core.rmem_max = 600000000"
append_to_file $FILE_SYSCTL "net.core.wmem_max = 600000000"
# load the updates
sysctl -p

# make sure to indicate we are done with phase one (needing a reboot)
touch $FLAG_AFTER_FIRST_REBOOT
echo "$CURRENT_DIR" > $FLAG_AFTER_FIRST_REBOOT

echo "First segment done.  Going for a reboot. Installation will automatically continue on reboot."
reboot
