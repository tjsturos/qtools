#!/bin/bash
# The aim of this is to get the current cron tasks file, add the line to run the on-start.sh script every reboot.
FILE_CRON=$QTOOLS_PATH/cron

append_to_file $FILE_CRON "GOROOT=/usr/local/go"
append_to_file $FILE_CRON "GOPATH=/root/go"
append_to_file $FILE_CRON "PATH=/root/go/bin:/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin"
append_to_file $FILE_CRON "QTOOLS_PATH=$QTOOLS_PATH"
append_to_file $FILE_CRON "1 0 * * * qtools make-backup"
append_to_file $FILE_CRON "1 */3 * * * qtools update"

# Load the updated file back into the crontab
crontab $FILE_CRON

# Finally remove the file we initially created as it's not needed.
rm $FILE_CRON
