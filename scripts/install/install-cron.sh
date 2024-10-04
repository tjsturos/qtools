#!/bin/bash
# HELP: Installs all the automated taks for this node.  Currently, it runs qtools & node updates, as well as backups (if enabled) every 10 minutes.  It also records the unclaimed balances on different intervals (every hour, 1x a day, 1x week, 1x month).
log "Updating this user's crontab for automated tasks..."

# The aim of this is to get the current cron tasks file, add the line to run the on-start.sh script every reboot.
FILE_CRON=$QTOOLS_PATH/cron
FILE_ACTUAL_OUTPUT="actual.txt"

remove_file $FILE_CRON false

append_to_file $FILE_CRON "GOROOT=$GOROOT" false
append_to_file $FILE_CRON "GOPATH=$GOPATH" false
append_to_file $FILE_CRON "PATH=${GOPATH}/bin:${GOROOT}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin" false
append_to_file $FILE_CRON "QTOOLS_PATH=$QTOOLS_PATH" false
append_to_file $FILE_CRON "@reboot qtools start" false

AUTO_UPDATE_NODE=$(yq eval '.scheduled_tasks.updates.node.enabled // true' $QTOOLS_CONFIG_FILE)

if [ "$AUTO_UPDATE_NODE" == "true" ]; then
  NODE_UPDATE_CRON_EXPRESSION=$(yq eval '.scheduled_tasks.updates.node.cron_expression // "*/10 * * * *"' $QTOOLS_CONFIG_FILE)
  
  # Check if Expression is valid
  if [ -z "$NODE_UPDATE_CRON_EXPRESSION" ]; then
    log "Error: Node update cron expression is empty. Using default value."
    NODE_UPDATE_CRON_EXPRESSION="*/10 * * * *"
  fi
  
  append_to_file $FILE_CRON "$NODE_UPDATE_CRON_EXPRESSION qtools update-node --auto" false
fi

AUTO_UPDATE_QTOOLS=$(yq eval '.scheduled_tasks.updates.qtools.enabled // true' $QTOOLS_CONFIG_FILE)

if [ "$AUTO_UPDATE_QTOOLS" == "true" ]; then
  QTOOLS_UPDATE_CRON_EXPRESSION=$(yq eval '.scheduled_tasks.updates.qtools.cron_expression // "*/10 * * * *"' $QTOOLS_CONFIG_FILE)
  
  # Check if Expression is valid
  if [ -z "$QTOOLS_UPDATE_CRON_EXPRESSION" ]; then
    log "Error: Qtools update cron expression is empty. Using default value."
    QTOOLS_UPDATE_CRON_EXPRESSION="*/10 * * * *"
  fi
  
  append_to_file $FILE_CRON "$QTOOLS_UPDATE_CRON_EXPRESSION qtools self-update --auto" false
fi

AUTO_RUN_DIAGNOSTICS=$(yq eval '.scheduled_tasks.diagnostics.enabled // false' $QTOOLS_CONFIG_FILE)

if [ "$AUTO_RUN_DIAGNOSTICS" == "true" ]; then
  DIAGNOSTICS_CRON_EXPRESSION=$(yq eval '.scheduled_tasks.diagnostics.cron_expression // "*/10 * * * *"' $QTOOLS_CONFIG_FILE)
  
  # Check if Expression is valid
  if [ -z "$DIAGNOSTICS_CRON_EXPRESSION" ]; then
    log "Error: Diagnostics cron expression is empty. Using default value."
    DIAGNOSTICS_CRON_EXPRESSION="*/10 * * * *"
  fi
  
  append_to_file $FILE_CRON "$DIAGNOSTICS_CRON_EXPRESSION qtools run-diagnostics --auto" false
fi

AUTO_BACKUP_STORE=$(yq eval '.scheduled_tasks.backup.enabled // false' $QTOOLS_CONFIG_FILE)

if [ "$AUTO_BACKUP_STORE" == "true" ]; then
  BACKUP_STORE_CRON_EXPRESSION=$(yq eval '.scheduled_tasks.backup.cron_expression // "*/10 * * * *"' $QTOOLS_CONFIG_FILE)
  
  # Check if Expression is valid
  if [ -z "$BACKUP_STORE_CRON_EXPRESSION" ]; then
    log "Error: Backup store cron expression is empty. Using default value."
    BACKUP_STORE_CRON_EXPRESSION="*/10 * * * *"
  fi
  
  append_to_file $FILE_CRON "$BACKUP_STORE_CRON_EXPRESSION qtools backup-store" false
fi

STATS_ENABLED=$(yq eval '.scheduled_tasks.statistics.enabled // false' $QTOOLS_CONFIG_FILE)

if [ "$STATS_ENABLED" == "true" ]; then
  append_to_file $FILE_CRON '0 * * * * qtools record-unclaimed-rewards hourly' false
  append_to_file $FILE_CRON '0 0 * * * qtools record-unclaimed-rewards daily' false
  append_to_file $FILE_CRON '0 0 * * 0 qtools record-unclaimed-rewards weekly' false
  append_to_file $FILE_CRON '0 0 1 * * qtools record-unclaimed-rewards monthly' false
fi


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