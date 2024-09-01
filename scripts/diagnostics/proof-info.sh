#!/bin/bash
# HELP: Fetches proof information from the log file

if [ "$IS_APP_FINISHED_STARTING" != "true" ]; then
    echo "App is still starting. Proof information may not be available yet."
    exit 0
fi

fetch_proof_info() {
    local UPTIME="$(get_last_started_at)"
    local LOG_OUTPUT=$(sed -n "/$UPTIME/,\$p" "$QUIL_LOG_FILE")
    
    local LAST_STORING_PROOF=$(echo "$LOG_OUTPUT" | grep "storing proof" | tail -n 1)
    local LAST_COMPLETED_PROOF=$(echo "$LOG_OUTPUT" | grep "completed duration proof" | tail -n 1)

    local STORING_INCREMENT=$(echo "$LAST_STORING_PROOF" | sed -n 's/.*"increment":\([0-9]*\).*/\1/p')
    local COMPLETED_INCREMENT=$(echo "$LAST_COMPLETED_PROOF" | sed -n 's/.*"increment":\([0-9]*\).*/\1/p')
    local TIME_TAKEN=$(echo "$LAST_COMPLETED_PROOF" | sed -n 's/.*"time_taken":\([0-9.]*\).*/\1/p')

    echo "STORING_INCREMENT=$STORING_INCREMENT"
    echo "COMPLETED_INCREMENT=$COMPLETED_INCREMENT"
    echo "TIME_TAKEN=$TIME_TAKEN"
}

fetch_proof_info