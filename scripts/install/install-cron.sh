#!/bin/bash
log "Updating this user's crontab for automated tasks..."

# The aim of this is to get the current cron tasks file, add the line to run the on-start.sh script every reboot.
FILE_CRON=$QTOOLS_PATH/cron
FILE_ACTUAL_OUTPUT="actual.txt"

remove_file $FILE_CRON false

append_to_file $FILE_CRON "GOROOT=$GOROOT" false
append_to_file $FILE_CRON "GOPATH=$GOPATH" false
append_to_file $FILE_CRON "PATH=\$GOPATH/bin:\$GOROOT/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin" false
append_to_file $FILE_CRON "QTOOLS_PATH=$QTOOLS_PATH" false
append_to_file $FILE_CRON '1 0 * * * qtools make-backup' false
append_to_file $FILE_CRON '*/10 * * * * qtools self-update && qtools update-node' false
append_to_file $FILE_CRON '0 */10 * * * qtools record-unclaimed-rewards' false

echo "$(crontab -l)" > $FILE_ACTUAL_OUTPUT
DIFF_BEFORE="$(colordiff -u $FILE_CRON $FILE_ACTUAL_OUTPUT)"
if [[ $DIFF_BEFORE ]]; then
  log "The crontab needs to be updated. Updating..."

  # Load the updated file back into the crontab
  crontab $FILE_CRON

  # Get the actual output of 'ufw status'
  echo "$(crontab -l)" > $FILE_ACTUAL_OUTPUT
  DIFF_AFTER="$(colordiff -u $FILE_CRON $FILE_ACTUAL_OUTPUT)"

  if [[ $DIFF_AFTER ]]; then
    log "$(echo -e \"The crontab was contains some errors:\n$DIFF_AFTER\")"
  else
    log "The crontab was successfully updated."
  fi
else 
  log "The crontab does not need to be updated.  Skipping."
fi

# cleanup files
remove_file $FILE_CRON false
remove_file $FILE_ACTUAL_OUTPUT false
