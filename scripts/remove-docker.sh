#!/bin/bash

cd ~/ceremonyclient

mv .config/keys.yml node/.config/keys.yml
mv .config/config.yml node/.config/config.yml

docker compose down

docker system prune -a -y
apt-get purge -y docker-engine docker docker.io docker-ce docker-ce-cli docker-compose-plugin
apt-get autoremove -y --purge docker-engine docker docker.io docker-ce docker-compose-plugin

rm -rf /var/lib/docker /etc/docker
groupdel docker
rm -rf /var/run/docker.sock
rm -rf /var/lib/containerd
rm -r ~/.docker
rm /usr/share/keyrings/docker-archive-keyring.gpg

rm ~/docker-ce ~/apt ~/updateapt-cache ~/policy
