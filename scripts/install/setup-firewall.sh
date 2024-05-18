#!/bin/bash

log "setting up firewall"
echo "y" | ufw enable
ufw allow 22
ufw allow 8336
ufw allow 443

expected_output="Status: active

To                         Action      From
--                         ------      ----
22                         ALLOW       Anywhere
8336                       ALLOW       Anywhere
443                        ALLOW       Anywhere
22 (v6)                    ALLOW       Anywhere (v6)
8336 (v6)                  ALLOW       Anywhere (v6)
443 (v6)                   ALLOW       Anywhere (v6)
"

# Get the actual output of 'ufw status'
actual_output=$(ufw status)

# Compare the actual output with the expected output
if [[ "$actual_output" == "$expected_output" ]]; then
  log "The firewall rules were successfully applied."
  exit 0
else
  log "The firewall rules were not applied successfully."
  log "Expected:"
  log "$expected_output"
  log "Actual:"
  log "$actual_output"
  exit 1
fi
