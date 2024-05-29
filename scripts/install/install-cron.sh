#!/bin/bash
# The aim of this is to get the current cron tasks file, add the line to run the on-start.sh script every reboot.
FILE_CRON=$QTOOLS_PATH/cron

append_to_file $FILE_CRON "GOROOT=/usr/local/go" false
append_to_file $FILE_CRON "GOPATH=/root/go" false
append_to_file $FILE_CRON "PATH=/root/go/bin:/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin" false
append_to_file $FILE_CRON "QTOOLS_PATH=$QTOOLS_PATH" false
append_to_file $FILE_CRON "1 0 * * * qtools make-backup" false
append_to_file $FILE_CRON "*/10 * * * * qtools self-update && qtools update-node" false

# Load the updated file back into the crontab
crontab $FILE_CRON

# Finally remove the file we initially created as it's not needed.
remove_file $FILE_CRON false

expected_output="GOROOT=/usr/local/go
GOPATH=/root/go
PATH=/root/go/bin:/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin
QTOOLS_PATH=$QTOOLS_PATH
1 0 * * * qtools make-backup
*/10 * * * * qtools self-update && qtools update-node"

# Get the actual output of 'ufw status'
actual_output=$(crontab -l)






if [[ "$actual_output" == "$expected_output" ]]; then
  echo "The crontab was successfully updated."
  exit 0
else
  expected_file="expected.txt"
  actual_file="actual.txt"
  echo $expected_output >> $expected_file
  echo $actual_output > $actual_output
  colordiff -u $expected_file $actual_file
  rm $expected_file
  rm $actual_file
  exit 1
fi

