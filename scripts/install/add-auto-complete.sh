#!/bin/bash

apt-get install bash-completion

append_to_file ~/.bashrc "source /etc/profile.d/bash_completion.sh"

source /etc/profile.d/bash_completion.sh

complete -W 'complete-install create-qtools-symlink install-go install-node-binary install-qclient-binary modify-config setup-cron setup-firewall purge remove-docker update-node' qtools