#!/bin/bash
# IGNORE
# Optimize network settings for macOS
FILE_SYSCTL=/etc/sysctl.conf

# Check if the file exists, create it if it doesn't
if [ ! -f "$FILE_SYSCTL" ]; then
    sudo touch "$FILE_SYSCTL"
fi

# Function to append to file if the line doesn't exist
append_to_file() {
    if ! grep -q "$2" "$1"; then
        echo "$2" | sudo tee -a "$1" > /dev/null
    fi
}

# Optimize receive and send buffer sizes
append_to_file $FILE_SYSCTL "kern.ipc.maxsockbuf=600000000"
append_to_file $FILE_SYSCTL "net.inet.tcp.sendspace=600000"
append_to_file $FILE_SYSCTL "net.inet.tcp.recvspace=600000"

# Load the updates
sudo sysctl -f $FILE_SYSCTL
