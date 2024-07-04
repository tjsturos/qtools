#!/bin/bash

# Function to get the unclaimed balance
get_unclaimed_balance() {
  # Replace with the actual command to get the unclaimed balance
  # For example: curl -s http://example.com/api/unclaimed_balance
  echo "$(qtools node-get-reward-balance)"  # Placeholder value, replace with actual command
}

TYPE="$1"

# Path to the CSV file
CSV_FILE="$QTOOLS_PATH/unclaimed_$TYPE_balance.csv"

# Check if the CSV file exists, if not, create it with headers
if [[ ! -f "$CSV_FILE" ]]; then
  echo "Timestamp,Balance" > "$CSV_FILE"
fi

# Get the current timestamp
TIMESTAMP=$(date +%s)

# Get the unclaimed balance
BALANCE=$(get_unclaimed_balance)

if [ ! -z "$BALANCE" ]; then
  # Append the timestamp and balance to the CSV file
  echo "$TIMESTAMP,$BALANCE" >> "$CSV_FILE"
fi