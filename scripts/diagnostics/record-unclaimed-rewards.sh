#!/bin/bash

# HELP: Records the current 'unclaimed' balance of this node to a CSV file. Must provide a param to indicate which type of recording it is.
# PARAM: "hourly"|"daily"|"weekly"|"monthly"
# Usage: qtools record-unclaimed-rewards hourly

# Function to get the unclaimed balance
get_unclaimed_balance() {
  echo "$(qtools unclaimed-balance)"
}

# Function to clean the CSV file of invalid entries
clean_csv_file() {
  local file="$1"
  local temp_file="${file}.temp"
  
  # Keep header and valid entries
  head -n 1 "$file" > "$temp_file"
  tail -n +2 "$file" | awk -F',' '$2 ~ /^[0-9]+(\.[0-9]+)?$/' >> "$temp_file"
  
  # Replace original file with cleaned file
  mv "$temp_file" "$file"
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
else
  # Clean the existing CSV file
  clean_csv_file "$CSV_FILE"
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