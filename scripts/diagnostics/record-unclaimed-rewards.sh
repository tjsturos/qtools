#!/bin/bash

# HELP: Records the current 'unclaimed' balance of this node to a CSV file. Must provide a param to indicate which type of recording it is.
# PARAM: "hourly"|"daily"|"weekly"|"monthly"
# Usage: qtools record-unclaimed-rewards hourly

# Function to get the unclaimed balance
get_unclaimed_balance() {
  echo "$(qtools unclaimed-balance)"
}

TYPE="$1"

if [ -z "$TYPE" ]; then
   log "A type must be provided to record to the correct file.  \
      Use 'hourly', 'daily', or 'weekly' as the first parameter, e.g. 'qtools record-unclaimed-rewards hourly'.  \
      Otherwise if you just wish to view, use 'qtools unclaimed-balance' command." 
   exit 1
fi

# Path to the CSV file
CSV_FILE="$QTOOLS_PATH/unclaimed_${TYPE}_balance.csv"

# Check if the CSV file exists, if not, create it with headers
if [[ ! -f "$CSV_FILE" ]]; then
  echo "Timestamp,Balance" > "$CSV_FILE"
fi

# Get the current timestamp
TIMESTAMP=$(date +%s)

# Get the unclaimed balance
BALANCE=$(get_unclaimed_balance)

# Check if BALANCE is a valid number
if [[ "$BALANCE" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
  # Append the timestamp and balance to the CSV file
  echo "$TIMESTAMP,$BALANCE" >> "$CSV_FILE"
else
  echo "Skipping record: Invalid balance value - $BALANCE"
fi