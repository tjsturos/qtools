#!/bin/bash

fetch_proof_info() {
    local UPTIME="$(get_last_started_at)"
    local JOURNAL_OUTPUT=$(sudo journalctl -u $QUIL_SERVICE_NAME@main --no-hostname -S "${UPTIME}")
    
    local LAST_STORING_PROOF=$(echo "$JOURNAL_OUTPUT" | grep "storing proof" | tail -n 1)
    local LAST_COMPLETED_PROOF=$(echo "$JOURNAL_OUTPUT" | grep "completed duration proof" | tail -n 1)

    local STORING_INCREMENT=$(echo "$LAST_STORING_PROOF" | grep -oP '"increment":\K\d+')
    local COMPLETED_INCREMENT=$(echo "$LAST_COMPLETED_PROOF" | grep -oP '"increment":\K\d+')
    local TIME_TAKEN=$(echo "$LAST_COMPLETED_PROOF" | grep -oP '"time_taken":\K[\d.]+')

    echo "STORING_INCREMENT=$STORING_INCREMENT"
    echo "COMPLETED_INCREMENT=$COMPLETED_INCREMENT"
    echo "TIME_TAKEN=$TIME_TAKEN"
}

fetch_proof_info