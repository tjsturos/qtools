#!/bin/bash

# Read the current value of settings.slave
current_value=$(yq e '.settings.slave' "$QTOOLS_CONFIG_FILE")

# Toggle the value
if [ "$current_value" = "true" ]; then
    new_value="false"
else
    new_value="true"
fi

# Update the YAML file with the new value
yq e -i ".settings.slave = $new_value" "$QTOOLS_CONFIG_FILE"

# Output the change to the user
echo "The value of settings.slave has been changed from $current_value to $new_value"

qtools restart
