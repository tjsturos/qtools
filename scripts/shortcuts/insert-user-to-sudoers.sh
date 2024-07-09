#!/bin/bash
# HELP: Allows the current user to use sudo commands without a password.

# Get the current username
USER=$(whoami)

# Backup the original sudoers file
sudo cp /etc/sudoers /etc/sudoers.bak

# Insert the no password entry for the current user
echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo EDITOR='tee -a' visudo

# Verify the changes
echo "Verification of sudoers file after modification:"
sudo visudo -c

echo "Done. $USER can now run sudo commands without a password."