#!/bin/bash
# Test script for autocomplete parameter extraction

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Get the project root (parent of tests directory)
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Change to project root for relative paths to work
cd "$PROJECT_ROOT" || exit 1

# Simulate the completion function logic
test_param_extraction() {
  local param_line="$1"
  local expected_flags="$2"
  local test_name="$3"
  
  echo "Testing: $test_name"
  echo "Input: $param_line"
  
  # Extract the parameter definition part
  param_def=$(echo "$param_line" | sed 's/^# PARAM: //')
  
  # Extract part before colon (if colon exists) - this is the flag definition
  if [[ "$param_def" =~ ^([^:]+): ]]; then
    # Has colon - extract everything before the colon
    param_def=${BASH_REMATCH[1]}
  else
    # No colon - extract flags and comma-separated flags up to first space
    param_def=$(echo "$param_def" | sed -E 's/^([^[:space:]]+(,[[:space:]]*[^[:space:]]+)*).*/\1/' | head -c 200)
  fi
  
  # Trim whitespace
  param_def=$(echo "$param_def" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  
  echo "Extracted param_def: '$param_def'"
  
    # Extract flags from the parameter definition
    # Only proceed if param_def looks like it contains flags (starts with -)
    local params=()
    if [[ "$param_def" =~ ^- ]]; then
      # Remove argument placeholders like <int>, <string>, etc. before processing
      param_cleaned=$(echo "$param_def" | sed -E 's/<[^>]+>//g')
      # Replace commas with spaces to handle comma-separated flags
      param_normalized=$(echo "$param_cleaned" | tr ',' ' ' | sed 's/[[:space:]]\+/ /g')
      # Extract flags - match - or -- followed by alphanumerics and hyphens
      # Use --? to match one or two dashes
      flags=$(echo "$param_normalized" | grep -oE '(--?[a-zA-Z0-9][a-zA-Z0-9-]*)' 2>/dev/null)
    
    echo "Normalized: '$param_normalized'"
    echo "Flags found: '$flags'"
    
    if [ -n "$flags" ]; then
      while read -r flag; do
        # Final validation: must be a proper flag
        if [[ "$flag" =~ ^-[a-zA-Z0-9] ]] || [[ "$flag" =~ ^--[a-zA-Z0-9-]+ ]]; then
          params+=("$flag")
        fi
      done <<< "$flags"
    fi
  fi
  
  # Extract quoted values
  quoted_values=$(echo "$param_line" | grep -oE '"([^"]+)"' 2>/dev/null | sed 's/"//g')
  if [ -n "$quoted_values" ]; then
    while read -r value; do
      params+=("$value")
    done <<< "$quoted_values"
  fi
  
  local result=$(printf '%s ' "${params[@]}")
  result=$(echo "$result" | sed 's/[[:space:]]*$//')
  
  echo "Result: '$result'"
  echo "Expected: '$expected_flags'"
  
  if [ "$result" == "$expected_flags" ]; then
    echo "✓ PASS"
  else
    echo "✗ FAIL"
  fi
  echo ""
}

# Test cases
echo "=== Testing PARAM extraction ==="
echo ""

# Test 1: Simple flag with colon
test_param_extraction \
  "# PARAM: --on: Explicitly turn auto-updates on" \
  "--on" \
  "Simple flag with colon"

# Test 2: Simple flag without colon
test_param_extraction \
  "# PARAM: --off Explicitly turn auto-updates off" \
  "--off" \
  "Simple flag without colon"

# Test 3: Comma-separated flags
test_param_extraction \
  "# PARAM: -m, --memory: Check memory usage" \
  "-m --memory" \
  "Comma-separated flags"

# Test 4: Quoted values
test_param_extraction \
  '# PARAM: "hourly"|"daily"|"weekly"' \
  "hourly daily weekly" \
  "Quoted values"

# Test 5: Flag with description containing hyphens (should NOT match -updates)
test_param_extraction \
  "# PARAM: --active: Print only the active workers count" \
  "--active" \
  "Flag with description (should not match words in description)"

# Test 6: Multiple flags
test_param_extraction \
  "# PARAM: --core <int>: restart a specific worker/core by index" \
  "--core" \
  "Flag with argument"

echo "=== Testing full script parsing ==="
echo ""

# Test parsing an actual script file
test_script_file() {
  local script_file="$1"
  local expected_params="$2"
  local test_name="$3"
  
  echo "Testing: $test_name"
  echo "Script: $script_file"
  
  local params=()
  
  while IFS= read -r param_line; do
    # Extract the parameter definition part
    param_def=$(echo "$param_line" | sed 's/^# PARAM: //')
    
    # Extract part before colon (if colon exists) - this is the flag definition
    if [[ "$param_def" =~ ^([^:]+): ]]; then
      # Has colon - extract everything before the colon
      param_def=${BASH_REMATCH[1]}
    else
      # No colon - extract flags and comma-separated flags up to first space
      param_def=$(echo "$param_def" | sed -E 's/^([^[:space:]]+(,[[:space:]]*[^[:space:]]+)*).*/\1/' | head -c 200)
    fi
    
    # Trim whitespace
    param_def=$(echo "$param_def" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Extract flags from the parameter definition
    if [[ "$param_def" =~ ^- ]]; then
      # Remove argument placeholders like <int>, <string>, etc. before processing
      param_cleaned=$(echo "$param_def" | sed -E 's/<[^>]+>//g')
      param_normalized=$(echo "$param_cleaned" | tr ',' ' ' | sed 's/[[:space:]]\+/ /g')
      # Use --? to match one or two dashes
      flags=$(echo "$param_normalized" | grep -oE '(--?[a-zA-Z0-9][a-zA-Z0-9-]*)' 2>/dev/null)
      
      if [ -n "$flags" ]; then
        while read -r flag; do
          # Final validation: must be a proper flag (single - or double --)
          if [[ "$flag" =~ ^-[a-zA-Z0-9] ]] || [[ "$flag" =~ ^--[a-zA-Z0-9-]+ ]]; then
            params+=("$flag")
          fi
        done <<< "$flags"
      fi
    fi
    
    # Extract quoted values
    quoted_values=$(echo "$param_line" | grep -oE '"([^"]+)"' 2>/dev/null | sed 's/"//g')
    if [ -n "$quoted_values" ]; then
      while read -r value; do
        params+=("$value")
      done <<< "$quoted_values"
    fi
  done < <(grep "^# PARAM:" "$script_file" 2>/dev/null)
  
  local result=$(printf '%s ' "${params[@]}" | sed 's/[[:space:]]*$//')
  
  echo "Result: '$result'"
  echo "Expected: '$expected_params'"
  
  if [ "$result" == "$expected_params" ]; then
    echo "✓ PASS"
  else
    echo "✗ FAIL"
  fi
  echo ""
}

# Test with actual script file
if [ -f "scripts/shortcuts/toggle-auto-update-node.sh" ]; then
  test_script_file \
    "scripts/shortcuts/toggle-auto-update-node.sh" \
    "--on --off" \
    "toggle-auto-update-node.sh"
fi

if [ -f "scripts/grpc/worker-count.sh" ]; then
  test_script_file \
    "scripts/grpc/worker-count.sh" \
    "--active --running" \
    "worker-count.sh"
fi
