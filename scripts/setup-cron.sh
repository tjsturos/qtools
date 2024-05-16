#!/bin/bash
# The aim of this is to get the current cron tasks file, add the line to run the on-start.sh script every reboot.
FILE_INITIAL_CRON=~/initial-cron

# Update the saved cron file with the @restart task

append_to_file $FILE_INITIAL_CRON "GOROOT=/usr/local/go"
append_to_file $FILE_INITIAL_CRON "GOPATH=/root/go"
append_to_file $FILE_INITIAL_CRON "PATH=/root/go/bin:/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin"
append_to_file $FILE_INITIAL_CRON "@reboot $CURRENT_DIR/install.sh"

# Load the updated file back into the crontab
crontab $FILE_INITIAL_CRON

# Finally remove the file we initially created as it's not needed.
rm $FILE_INITIAL_CRON
