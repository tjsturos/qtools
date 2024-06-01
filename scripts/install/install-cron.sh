#!/bin/bash
# The aim of this is to get the current cron tasks file, add the line to run the on-start.sh script every reboot.
FILE_CRON=$QTOOLS_PATH/cron

append_to_file $FILE_CRON "GOROOT=$GOROOT" false
append_to_file $FILE_CRON "GOPATH=$GOPATH" false
append_to_file $FILE_CRON "PATH=\$GOPATH/bin:\$GOROOT/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin" false
append_to_file $FILE_CRON "QTOOLS_PATH=$QTOOLS_PATH" false
append_to_file $FILE_CRON "1 0 * * * qtools make-backup" false
append_to_file $FILE_CRON "*/10 * * * * qtools self-update && qtools update-node" false

# Load the updated file back into the crontab
crontab $FILE_CRON

# Get the actual output of 'ufw status'
actual_output=$(crontab -l)

if [[ "$actual_output" == "$FILE_CRON" ]]; then
  echo "The crontab was successfully updated."
  exit 0
else
  actual_file="actual.txt"
  echo $actual_output > $actual_file
  colordiff -u $FILE_CRON $actual_file
  remove_file $FILE_CRON
  remove_file $actual_file
  exit 1
fi

