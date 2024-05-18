#/bin/bash

# add commands to this file to customize your image further

# make sure bandwidth is optimized 
FILE_SYSCTL=/etc/sysctl.conf
append_to_file $FILE_SYSCTL "net.core.rmem_max = 600000000"
append_to_file $FILE_SYSCTL "net.core.wmem_max = 600000000"
# load the updates
sysctl -p

# Setup firewall
qtools setup-firewall &
