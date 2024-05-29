#!/bin/bash

cd $QUIL_PATH

qtools make-backup

docker compose down

docker system prune -a -y
apt-get purge -y docker-engine docker docker.io docker-ce docker-ce-cli docker-compose-plugin
apt-get autoremove -y --purge docker-engine docker docker.io docker-ce docker-compose-plugin

log "Removing docker files..."
remove_directory /var/lib/docker false
remove_directory /etc/docker false
groupdel docker
remove_directory /var/run/docker.sock false
remove_directory /var/lib/containerd false
remove_directory ~/.docker false

remove_file /usr/share/keyrings/docker-archive-keyring.gpg false
remove_file /root/docker-ce false
remove_file /root/apt false
remove_file /root/updateapt-cache false
remove_file /root/policy false

remove_directory $QUIL_PATH false

qtools complete-install
