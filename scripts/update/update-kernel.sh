#!/bin/bash

echo "Updating package list and upgrading all packages..."
sudo apt update -y
sudo apt upgrade -y

# Ensure all kernel-related packages are installed and up-to-date
echo "Upgrading kernel packages..."
sudo apt install -y linux-generic

# Reboot the system
echo "Rebooting the system to apply the new kernel..."
sudo reboot
