#!/bin/bash
# HELP: Updates this node\'s server\'s hostname. Requires an input for the new hostname.
# PARAM: <string>: name of the machine to use
# Usage: qtools update-hostname quil-miner-101

if [ -z "$1" ]; then
  echo "Usage: $0 NEW_HOSTNAME"
  exit 1
fi

NEW_HOSTNAME=$1

# Change the hostname for the current session
sudo hostnamectl set-hostname $NEW_HOSTNAME

# Update the hostname in /etc/hostname
echo $NEW_HOSTNAME | sudo tee /etc/hostname

# Update the hostname in /etc/hosts
sudo sed -i "s/127.0.0.1 .*/127.0.0.1 $NEW_HOSTNAME/" /etc/hosts
sudo sed -i "s/127.0.1.1 .*/127.0.1.1 $NEW_HOSTNAME/" /etc/hosts

echo "Hostname changed to $NEW_HOSTNAME. Reboot to apply changes."