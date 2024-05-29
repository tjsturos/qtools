#!/bin/bash

log "Setting up firewall"
echo "y" | ufw enable
ufw allow 22
ufw allow 8336
ufw allow 443

expected_rules=(
  "22                         ALLOW       Anywhere"
  "8336                       ALLOW       Anywhere"
  "443                        ALLOW       Anywhere"
  "22 (v6)                    ALLOW       Anywhere (v6)"
  "8336 (v6)                  ALLOW       Anywhere (v6)"
  "443 (v6)                   ALLOW       Anywhere (v6)"
)

# Get the actual output of 'ufw status'
actual_output=$(ufw status)

# Check if UFW is active
if ! echo "$actual_output" | grep -q "Status: active"; then
  log "UFW is not active."
  exit 1
fi

# Check each expected rule
missing_rules=()
for rule in "${expected_rules[@]}"; do
  if ! echo "$actual_output" | grep -q "$rule"; then
    missing_rules+=("$rule")
  fi
done

# Report results
if [ ${#missing_rules[@]} -eq 0 ]; then
  log "All expected rules are present in the UFW status."
else
  log "The following expected rules are missing in the UFW status:"
  for rule in "${missing_rules[@]}"; do
    log "$rule"
  done
  exit 1
fi
