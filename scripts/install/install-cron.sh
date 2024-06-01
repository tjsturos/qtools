#!/bin/bash
log "Updating this user's crontab for automated tasks"
# The aim of this is to get the current cron tasks file, add the line to run the on-start.sh script every reboot.
FILE_CRON=$QTOOLS_PATH/cron

remove_file $FILE_CRON false

append_to_file $FILE_CRON "GOROOT=$GOROOT" false
append_to_file $FILE_CRON "GOPATH=$GOPATH" false
append_to_file $FILE_CRON "PATH=\$GOPATH/bin:\$GOROOT/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin" false
append_to_file $FILE_CRON "QTOOLS_PATH=$QTOOLS_PATH" false
append_to_file $FILE_CRON '1 0 * * * qtools make-backup' false
append_to_file $FILE_CRON '*/10 * * * * qtools self-update && qtools update-node' false

# Load the updated file back into the crontab
crontab $FILE_CRON

# Get the actual output of 'ufw status'
FILE_ACTUAL_OUTPUT="actual.txt"
echo "$(crontab -l)" > $FILE_ACTUAL_OUTPUT
diff="$(colordiff -u $FILE_CRON $FILE_ACTUAL_OUTPUT)"

if [[ $diff ]]; then
  log "$(echo -e \"The crontab was contains some errors:\n$diff\")"
else
  log "The crontab was successfully updated."
fi

remove_file $FILE_CRON false
remove_file $FILE_ACTUAL_OUTPUT false
