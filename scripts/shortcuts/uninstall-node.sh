
# Stop the node
qtools stop

# backup and verify integrity
if ! qtools verify-backup-integrity; then
    read -p "Backup integrity check failed. Do you want to continue with the uninstallation? (y/N): " response
    if [[ ! $response =~ ^[Yy]$ ]]; then
        echo "Uninstallation aborted."
        exit 1
    fi
fi

qtools update-hostname ubuntu

# remove tailscale
qtools install-tailscale --uninstall

# Remove the node
sudo rm -rf $QUIL_PATH

# Remove the qtools
sudo rm -rf $QTOOLS_BIN_PATH
sudo rm -rf $QTOOLS_PATH

# Empty the crontab for the current user
crontab -r

# Confirm that the crontab is empty
if [ -z "$(crontab -l 2>/dev/null)" ]; then
    echo "Crontab has been successfully emptied."
else
    echo "Warning: Failed to empty the crontab. Please check manually."
fi





