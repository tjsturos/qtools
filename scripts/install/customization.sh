#/bin/bash
# IGNORE
# remove ubuntu pro messages
sudo mv /etc/apt/apt.conf.d/20apt-esm-hook.conf /etc/apt/apt.conf.d/20apt-esm-hook.conf.bak
# make sure bandwidth is optimized
FILE_SYSCTL=/etc/sysctl.conf
append_to_file $FILE_SYSCTL "net.core.rmem_max = 600000000" false
append_to_file $FILE_SYSCTL "net.core.wmem_max = 600000000" false
append_to_file $FILE_SYSCTL "net.ipv4.tcp_fastopen = 3" false
append_to_file $FILE_SYSCTL "net.ipv4.ip_local_port_range = 30000 49999" false
append_to_file $FILE_SYSCTL "net.ipv6.conf.all.disable_ipv6 = 1" false
append_to_file $FILE_SYSCTL "net.ipv6.conf.default.disable_ipv6 = 1" false
append_to_file $FILE_SYSCTL "net.ipv6.conf.lo.disable_ipv6 = 1" false

# load the updates
sudo sysctl -p
