#/bin/bash
source $HOME/.bashrc
STORED_PATH=$(cat ~/saved-path)
PATH=$STORED_PATH
log "Loading stored path: $STORED_PATH"
#install quilibrium from github
# TODO: update to official Quilibrium mirror once available
log "cloning Quilibrium repo"
cd $HOME && git clone https://github.com/QuilibriumNetwork/ceremonyclient.git

# setup firewall
log "setting up firewall"
echo "y" | ufw enable
ufw allow 22
ufw allow 8336
ufw allow 443

# if there are any customizations, run them now
if [[ -f $FILE_SETUP_CUSTOMIZATION ]]; then
    log "running customization"
    source $FILE_SETUP_CUSTOMIZATION
fi

log "The path is: $PATH"
cd $HOME/ceremonyclient/node
GOEXPERIMENT=arenas go install  ./... >> $CURRENT_DIR/$FILE_LOG

sleep 30

sed -i 's/^ *listenGrpcMultiaddr:.*$/  listenGrpcMultiaddr: \/ip4\/127.0.0.1\/tcp\/8337/' ./.config/config.yml
sed -i '/^ *engine: *$/a \  statsMultiaddr: "/dns/stats.quilibrium.com/tcp/443"' ./.config/config.yml

# If the backup files exist, copy to correct dir
source $CURRENT_DIR/scripts/backup/restore-backup.sh

# Copy the service to the systemd directory
cp $CURRENT_DIR/ceremonyclient.service /lib/systemd/system/

# tells server to start on reboot
systemctl enable ceremonyclient.service

# starts the service now
systemctl start ceremonyclient.service

# indicate that setup is now complete (so it's not run again)
log "setup complete"
touch $FLAG_SETUP_COMPLETE
echo "true" > $FLAG_SETUP_COMPLETE

# cleanup any leftovers
source $CURRENT_DIR/scripts/cleanup.sh