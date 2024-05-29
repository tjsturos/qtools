#!/bin/bash

log "Updating package list and upgrading all packages..."
sudo apt update -y
sudo apt upgrade -y

# Ensure all kernel-related packages are installed and up-to-date
log "Upgrading kernel packages..."
sudo apt install -y linux-generic

# remove old packages
apt-get autoremove -y

# Reboot the system
log "Rebooting the system to apply the new kernel..."
sudo reboot
