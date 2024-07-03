#/bin/bash

# make sure bandwidth is optimized 
FILE_SYSCTL=/etc/sysctl.conf
append_to_file $FILE_SYSCTL "net.core.rmem_max = 600000000" false
append_to_file $FILE_SYSCTL "net.core.wmem_max = 600000000" false
# load the updates
sudo sysctl -p
