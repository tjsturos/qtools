#!/bin/bash

# Define the file path
file_path="$QTOOLS_PATH/unclaimed_hourly_balance.csv"  # Replace with your actual file path

# Check if the file exists
if [[ ! -f "$file_path" ]]; then
  echo "File not found!"
  exit 1
fi

# Read the CSV file and process the data
# Extract the header and the last 24 lines
header=$(head -n 1 "$file_path")
data=$(tail -n +2 "$file_path")

# Convert the data to an array
IFS=$'\n' read -d '' -r -a lines <<< "$data"

# Get the number of lines
num_lines=${#lines[@]}

# Initialize variables
total_increase=0
prev_balance=0
first_line=true

# Find the start index for the last 24 hours
start_index=$((num_lines - 23))

# Process the last 24 hours of data
for ((i=start_index; i<num_lines; i++)); do
  # Read the line
  line=${lines[$i]}
  
  # Extract the timestamp and balance
  IFS=',' read -r timestamp balance <<< "$line"
  
  if [[ "$first_line" == true ]]; then
    prev_balance=$balance
    first_line=false
    continue
  fi
  
  # Calculate the difference between the current and previous balance
  increase=$(echo "$balance - $prev_balance" | bc)
  total_increase=$(echo "$total_increase + $increase" | bc)
  
  # Update the previous balance
  prev_balance=$balance
done

# Calculate the average increase
average_increase=$(echo "scale=10; $total_increase / 23" | bc)

# Output the result
echo "$average_increase"