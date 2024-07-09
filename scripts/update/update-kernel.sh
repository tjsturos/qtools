#!/bin/bash
# HELP: Installs new Linux kernals and removes old packages.

log "Updating package list and upgrading all packages..."
sudo apt update -y &> /dev/null
sudo apt upgrade -y &> /dev/null

# Ensure all kernel-related packages are installed and up-to-date
log "Upgrading kernel packages..."
sudo apt install -y linux-generic &> /dev/null

# remove old packages
sudo apt-get autoremove -y &> /dev/null

# Reboot the system
log "Rebooting the system to apply the new kernel..."
sudo reboot
