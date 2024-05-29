#!/bin/bash

# Function to edit sshd_config safely
edit_sshd_config() {
  local sshd_config="/etc/ssh/sshd_config"

  # Ensure the script is run as root
  if [[ $EUID -ne 0 ]]; then
    log "This script must be run as root" 1>&2
    exit 1
  fi

  # Backup the original sshd_config
  if [[ ! -f "${sshd_config}.bak" ]]; then
    cp "$sshd_config" "${sshd_config}.bak"
    log "Backup of sshd_config created at ${sshd_config}.bak"
  fi

  # Disable PasswordAuthentication and ChallengeResponseAuthentication
  sed -i 's/^#\?\s*PasswordAuthentication\s\+.*/PasswordAuthentication no/' "$sshd_config"
  sed -i 's/^#\?\s*ChallengeResponseAuthentication\s\+.*/ChallengeResponseAuthentication no/' "$sshd_config"

  # Add the directives if they do not exist in the file
  grep -q "^PasswordAuthentication" "$sshd_config" || echo "PasswordAuthentication no" >> "$sshd_config"
  grep -q "^ChallengeResponseAuthentication" "$sshd_config" || echo "ChallengeResponseAuthentication no" >> "$sshd_config"
}

# Function to restart SSH service
restart_ssh_service() {
  # Detect the operating system and restart the appropriate service
  if command -v systemctl >/dev/null 2>&1; then
    systemctl restart ssh || systemctl restart sshd
  else
    service ssh restart || service sshd restart
  fi
}

# Main script execution
edit_sshd_config
restart_ssh_service

echo "Password logins via SSH have been disabled."