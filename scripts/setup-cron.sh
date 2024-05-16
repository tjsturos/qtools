#!/bin/bash
# The aim of this is to get the current cron tasks file, add the line to run the on-start.sh script every reboot.
FILE_INITIAL_CRON=~/initial-cron

# Update the saved cron file with the @restart task
echo "\nGOROOT=/usr/local/go\nGOPATH=$HOME/go\nPATH=/bin:/usr/bin:$HOME/go/bin:/usr/local/go/bin" > $FILE_INITIAL_CRON
echo "@reboot $CURRENT_DIR/install.sh" >> $FILE_INITIAL_CRON
echo "1 */3 * * * $CURRENT_DIR/scripts/update.sh" >> $FILE_INITIAL_CRON

# Load the updated file back into the crontab
crontab $FILE_INITIAL_CRON

# Finally remove the file we initially created as it's not needed.
rm $FILE_INITIAL_CRON
