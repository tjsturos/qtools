#!/bin/bash
# HELP: Updates macOS system software and kernel

log "Checking for macOS software updates..."
softwareupdate -l

log "Installing all available updates..."
sudo softwareupdate -i -a

log "Cleaning up old system files..."
sudo tmutil deletelocalsnapshots / &> /dev/null

log "Clearing system and user caches..."
sudo purge

log "Update complete. A restart may be required to apply all changes."
read -p "Do you want to restart now? (y/n) " choice
case "$choice" in 
  y|Y ) 
    log "Restarting the system..."
    sudo shutdown -r now
    ;;
  * ) 
    log "Please remember to restart your system soon to apply all updates."
    ;;
esac
