#!/bin/bash

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

NEW_USER="quilibrium"
GROUP="quilibrium"

# Check if the group exists, if not, create it
if ! getent group "$GROUP" > /dev/null 2>&1; then
    echo "Group $GROUP does not exist. Creating group $GROUP."
    groupadd "$GROUP"
    if [ $? -ne 0 ]; then
        echo "Failed to create group $GROUP"
        exit 1
    fi
fi

# Create the new user and add to the specified group
useradd -m -s /bin/bash -G "$GROUP" "$NEW_USER"
if [ $? -ne 0 ]; then
    echo "Failed to create user $NEW_USER"
    exit 1
fi
usermod -aG sudo $NEW_USER
if id -nG "$NEW_USER" | grep -qw "$GROUP"; then
    echo "User $NEW_USER has been added to the $GROUP group and now has sudo privileges."
else
    echo "Failed to add user $NEW_USER to the $GROUP group."
    exit 1
fi

cp /etc/sudoers /etc/sudoers.bak

# Add the no-password sudo rule for the user
echo "$NEW_USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Verify the sudoers file for syntax errors
if visudo -c &>/dev/null; then
    echo "Updated /etc/sudoers successfully."
else
    echo "Failed to update /etc/sudoers. Restoring backup."
    mv /etc/sudoers.bak /etc/sudoers
    exit 1
fi

# Set up .ssh directory for the new user
export USER_HOME=$(eval echo "~$NEW_USER")
SSH_DIR="$USER_HOME/.ssh"

mkdir -p "$SSH_DIR"
if [ $? -ne 0 ]; then
    echo "Failed to create .ssh directory for $NEW_USER"
    exit 1
fi

# Copy the root's authorized_keys to the new user
cp /root/.ssh/authorized_keys "$SSH_DIR/"
if [ $? -ne 0 ]; then
    echo "Failed to copy SSH keys to $NEW_USER's .ssh directory"
    exit 1
fi

# Set the correct permissions
chown -R "$NEW_USER:$NEW_USER" "$SSH_DIR"
chmod 700 "$SSH_DIR"
chmod 600 "$SSH_DIR/authorized_keys"

# Add Go environment
BASHRC=$USER_HOME/.bashrc
append_to_file $BASHRC "export GOROOT=/usr/local/go"
append_to_file $BASHRC "export GOPATH=$USER_HOME/go"
append_to_file $BASHRC "export PATH=\$GOPATH/bin:\$GOROOT/bin:\$PATH"

# Disable root SSH login
SSHD_CONFIG="/etc/ssh/sshd_config"
sed -i.bak 's/^PermitRootLogin .*/PermitRootLogin no/' "$SSHD_CONFIG"
if ! grep -q "^PermitRootLogin no" "$SSHD_CONFIG"; then
    echo "PermitRootLogin no" >> "$SSHD_CONFIG"
fi

# Restart SSH service to apply changes
systemctl restart sshd

echo "User $NEW_USER created and configured for SSH access."
echo "Root login via SSH has been disabled."