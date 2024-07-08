#!/bin/bash

# Define the file path
file_path="$QTOOLS_PATH/unclaimed_hourly_balance.csv"  # Replace with your actual file path

# Check if the file exists
if [[ ! -f "$file_path" ]]; then
  echo "File not found!"
  exit 1
fi

# Read the number of hours from the user, default to 24 if not provided
hours=${1:-24}

# Read the CSV file and process the data
# Extract the header and the rest of the data
header=$(head -n 1 "$file_path")
data=$(tail -n +2 "$file_path")

# Convert the data to an array
IFS=$'\n' read -d '' -r -a lines <<< "$data"

# Get the number of lines
num_lines=${#lines[@]}

# Adjust hours if there are fewer records than the specified number of hours
if [[ $num_lines -lt $hours ]]; then
  hours=$num_lines
  echo "Not enough records for the specified number of hours. Defaulting to the maximum available records: $hours hours."
fi

# Initialize variables
total_increase=0
prev_balance=0
first_line=true

# Find the start index for the specified number of hours
start_index=$((num_lines - hours + 1))

# Process the specified number of hours of data
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
average_increase=$(echo "scale=10; $total_increase / ($hours - 1)" | bc)

# Output the result
echo "$average_increase"
