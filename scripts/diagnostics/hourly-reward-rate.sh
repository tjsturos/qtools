#!/bin/bash
# HELP: Will return the average hourly rate, by default will use the last 24 hours.  Can set optional param to limit or expand range.
# PARAM 1: <integer>: The number of hours to use to average
# Usage: qtools hourly-reward-rate 1 
# Usage: qtools hourly-reward-rate

# Define the file path
file_path="$QTOOLS_PATH/unclaimed_hourly_balance.csv"  # Replace with your actual file path

# Check if the file exists
if [[ ! -f "$file_path" ]]; then
  echo "File not found!"
  exit 1
fi

# Read the number of hours from the user, default to 24 if not provided
hours=${1:-24}

# Check if the input is a non-integer or less than 1
if ! [[ "$hours" =~ ^[0-9]+$ ]] || [[ "$hours" -le 0 ]]; then
  exit 1
fi

# Read the CSV file and process the data
# Extract the header and the rest of the data
header=$(head -n 1 "$file_path")
data=$(tail -n +2 "$file_path")

# Convert the data to an array
IFS=$'\n' read -d '' -r -a lines <<< "$data"

# Get the number of lines
num_lines=${#lines[@]}

# Ensure there are enough records to calculate the average for the given hours
if [[ $num_lines -lt 2 ]]; then
  echo "Not enough records to calculate any reward increase. Minimum of 2 hours of run-time."
  exit 1
fi

# Adjust hours if there are fewer records than the specified number of hours
if [[ $num_lines -lt $hours ]]; then
  hours=$num_lines
  echo "Not enough records for the specified number of hours. Defaulting to the maximum available records: $hours hours."
fi

# Initialize variables
total_increase=0
prev_balance=0
prev_timestamp=0
first_line=true
valid_intervals=0

# Find the start index for the specified number of hours
start_index=$((num_lines - hours))

# Process the specified number of hours of data
for ((i=start_index; i<num_lines; i++)); do
  # Read the line
  line=${lines[$i]}
  
  # Extract the timestamp and balance
  IFS=',' read -r timestamp balance <<< "$line"
  
  # Skip invalid lines
  if [[ -z "$timestamp" || -z "$balance" ]]; then
    continue
  fi

  if [[ "$first_line" == true ]]; then
    prev_balance=$balance
    prev_timestamp=$timestamp
    first_line=false
    continue
  fi

  # Calculate the difference between the current and previous timestamp
  timestamp_diff=$((timestamp - prev_timestamp))
  
  # Skip records with non-hourly gaps
  if [[ $timestamp_diff -gt 3600 ]]; then
    prev_balance=$balance
    prev_timestamp=$timestamp
    continue
  fi

  # Calculate the difference between the current and previous balance
  increase=$(echo "$balance - $prev_balance" | bc)
  total_increase=$(echo "$total_increase + $increase" | bc)
  
  # Update the previous balance and timestamp
  prev_balance=$balance
  prev_timestamp=$timestamp
  valid_intervals=$((valid_intervals + 1))
done

# Ensure there are valid intervals to calculate the average
if [[ $valid_intervals -lt 1 ]]; then
  exit 1
fi

# Calculate the average increase
average_increase=$(echo "scale=10; $total_increase / $valid_intervals" | bc)

# Format the result to always have a leading zero before the decimal point
formatted_increase=$(echo "$average_increase" | awk '{printf "%.10f", $0}')

# Output the result
echo "$formatted_increase"
