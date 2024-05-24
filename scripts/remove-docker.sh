#!/bin/bash

cd $QUIL_PATH

qtools make-backup

docker compose down

docker system prune -a -y
apt-get purge -y docker-engine docker docker.io docker-ce docker-ce-cli docker-compose-plugin
apt-get autoremove -y --purge docker-engine docker docker.io docker-ce docker-compose-plugin

remove_directory /var/lib/docker 
remove_directory /etc/docker
groupdel docker
remove_directory /var/run/docker.sock
remove_directory /var/lib/containerd
remove_directory $HOME/.docker

remove_file /usr/share/keyrings/docker-archive-keyring.gpg
remove_file $HOME/docker-ce
remove_file $HOME/apt
remove_file $HOME/updateapt-cache
remove_file $HOME/policy

remove_directory $QUIL_PATH

qtools complete-install
