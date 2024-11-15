#!/bin/bash

# Get SSH port and allowed IP from config
SSH_PORT=$(yq '.ssh.port // 22' $QTOOLS_CONFIG_FILE)
ALLOW_FROM_IP=$(yq '.ssh.allow_from_ip' $QTOOLS_CONFIG_FILE)

# Check if --ip parameter is provided
while [[ $# -gt 0 ]]; do
    case $1 in
        --ip)
            if [[ -n "$2" && "$2" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                ALLOW_FROM_IP="$2"
                echo "IP address set to $ALLOW_FROM_IP"
            else
                echo "Error: Invalid IP address provided."
                exit 1
            fi
            shift 2
            ;;
        --port)
            SSH_PORT="$2"
            echo "SSH port set to $SSH_PORT"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done




# Check if ALLOW_FROM_IP is set and not false
if [ -n "$ALLOW_FROM_IP" ] && [ "$ALLOW_FROM_IP" != "false" ]; then

    # Verify if ALLOW_FROM_IP is a valid IP address
    if ! [[ $ALLOW_FROM_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: $ALLOW_FROM_IP is not a valid IP address."
        exit 1
    fi

    # Delete existing rule for SSH port (if any)
    sudo ufw delete allow $SSH_PORT/tcp
    sudo ufw delete allow 22

    # Add new rule to allow SSH from specific IP
    sudo ufw allow from $ALLOW_FROM_IP to any port $SSH_PORT proto tcp

    yq eval -i ".ssh.port = $SSH_PORT" $QTOOLS_CONFIG_FILE
    yq eval -i ".ssh.allow_from_ip = '$ALLOW_FROM_IP'" $QTOOLS_CONFIG_FILE

    sudo ufw reload

    echo "UFW rule updated: SSH port $SSH_PORT allowed from IP $ALLOW_FROM_IP"
else
    echo "SSH allow from IP not set or disabled in config. No changes made to UFW rules."
fi

