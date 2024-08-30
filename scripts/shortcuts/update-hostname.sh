#!/bin/bash
# HELP: Updates this node's server's hostname. Requires an input for the new hostname.
# PARAM: <string>: name of the machine to use
# Usage: qtools update-hostname quil-miner-101

if [[ -z "$1" ]]; then
  echo "Usage: $0 NEW_HOSTNAME"
  exit 1
fi

NEW_HOSTNAME=$1

# Change the hostname for the current session
sudo scutil --set HostName "$NEW_HOSTNAME"
sudo scutil --set LocalHostName "$NEW_HOSTNAME"
sudo scutil --set ComputerName "$NEW_HOSTNAME"

# Update the hostname in /etc/hosts
sudo sed -i '' "s/^127\.0\.0\.1.*$/127.0.0.1 localhost $NEW_HOSTNAME/" /etc/hosts

echo "Hostname changed to $NEW_HOSTNAME. Changes will take effect after reboot or logout/login."
echo "Current hostname settings:"
echo "HostName: $(scutil --get HostName)"
echo "LocalHostName: $(scutil --get LocalHostName)"
echo "ComputerName: $(scutil --get ComputerName)"