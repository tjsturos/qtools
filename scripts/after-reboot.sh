#/bin/bash

# if there are any customizations, run them now
if [[ -f $FILE_SETUP_CUSTOMIZATION ]]; then
    log "running customization"
    source $FILE_SETUP_CUSTOMIZATION
fi

sleep 60

sed -i 's/^ *listenGrpcMultiaddr:.*$/  listenGrpcMultiaddr: \/ip4\/127.0.0.1\/tcp\/8337/' ./.config/config.yml
sed -i '/^ *engine: *$/a \  statsMultiaddr: "/dns/stats.quilibrium.com/tcp/443"' ./.config/config.yml
# If the backup files exist, copy to correct dir
source $CURRENT_DIR/scripts/backup/restore-backup.sh

# indicate that setup is now complete (so it's not run again)
log "setup complete"
touch $FLAG_SETUP_COMPLETE
echo "true" > $FLAG_SETUP_COMPLETE

# cleanup any leftovers, including removing the @reboot in cron
source $CURRENT_DIR/scripts/cleanup.sh


