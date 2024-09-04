#!/bin/bash
# HELP: Will return the average hourly rate, by default will use the last 24 hours. Can set optional param to limit or expand range.
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
total_hours=0
prev_balance=0
prev_timestamp=0
first_line=true

# Start from the last line and work backwards
for ((i=num_lines-1; i>=0; i--)); do
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

  # Calculate the difference between the current and previous timestamp in hours
  timestamp_diff=$(echo "scale=10; ($prev_timestamp - $timestamp) / 3600" | bc)
  
  # Calculate the difference between the current and previous balance
  increase=$(echo "$prev_balance - $balance" | bc)
  
  # Add to total increase and total hours
  total_increase=$(echo "$total_increase + $increase" | bc)
  total_hours=$(echo "$total_hours + $timestamp_diff" | bc)
  
  # Update the previous balance and timestamp
  prev_balance=$balance
  prev_timestamp=$timestamp

  # Break if we've reached or exceeded the desired number of hours
  if (( $(echo "$total_hours >= $hours" | bc -l) )); then
    break
  fi
done

# Ensure there are valid intervals to calculate the average
if (( $(echo "$total_hours < 0.1" | bc -l) )); then
  echo "Not enough valid data to calculate the hourly reward rate."
  exit 1
fi

# Calculate the hourly reward rate
hourly_rate=$(echo "scale=10; $total_increase / $total_hours" | bc)

# Format the result to always have a leading zero before the decimal point
formatted_rate=$(printf "%.10f" "$hourly_rate")

# Output the result
echo "$formatted_rate"
