#!/bin/bash
# HELP: Will change the SSH config to disallow using passwords to login to this node on macOS.

# Function to edit sshd_config safely
edit_sshd_config() {
    local sshd_config="/etc/ssh/sshd_config"
    # Ensure the script is run with sudo
    if [[ $EUID -ne 0 ]]; then
        log "This script must be run with sudo" 1>&2
        exit 1
    fi

    # Backup the original sshd_config
    if [[ ! -f "${sshd_config}.bak" ]]; then
        sudo cp "$sshd_config" "${sshd_config}.bak"
        log "Backup of sshd_config created at ${sshd_config}.bak"
    fi

    # Disable PasswordAuthentication and ChallengeResponseAuthentication
    sudo sed -i '' 's/^#\?\s*PasswordAuthentication\s\+.*/PasswordAuthentication no/' "$sshd_config"
    sudo sed -i '' 's/^#\?\s*ChallengeResponseAuthentication\s\+.*/ChallengeResponseAuthentication no/' "$sshd_config"

    # Add the directives if they do not exist in the file
    sudo grep -q "^PasswordAuthentication" "$sshd_config" || echo "PasswordAuthentication no" | sudo tee -a "$sshd_config" > /dev/null
    sudo grep -q "^ChallengeResponseAuthentication" "$sshd_config" || echo "ChallengeResponseAuthentication no" | sudo tee -a "$sshd_config" > /dev/null
}

# Function to restart SSH service on macOS
restart_ssh_service() {
    sudo launchctl unload /System/Library/LaunchDaemons/ssh.plist
    sudo launchctl load -w /System/Library/LaunchDaemons/ssh.plist
}

# Do not complete this action if the user does not actually have any authorized keys to use to log back into this node.
if [[ -z "$(cat ~/.ssh/authorized_keys)" ]]; then
    log "You must have at least one authorized key to complete this action-- if you do not have at least one authorized key, you will not be able to log back in."
    exit 1
fi

# Main script execution
edit_sshd_config
restart_ssh_service

log "Password logins via SSH have been disabled on macOS."