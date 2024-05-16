#/bin/bash

# if there are any customizations, run them now
if [[ -f $FILE_SETUP_CUSTOMIZATION ]]; then
    log "running customization"
    source $FILE_SETUP_CUSTOMIZATION
fi


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

sleep 30
sed -i 's/^ *listenGrpcMultiaddr:.*$/  listenGrpcMultiaddr: \/ip4\/127.0.0.1\/tcp\/8337/' ./.config/config.yml
sed -i '/^ *engine: *$/a \  statsMultiaddr: "/dns/stats.quilibrium.com/tcp/443"' ./.config/config.yml
