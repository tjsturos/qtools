#!/bin/bash
# HELP: Prints this node\'s version that is running in the service.

IS_LINKED="$(yq '.settings.linked_node.enabled' $QTOOLS_CONFIG_FILE)"

if [ "$IS_LINKED" == "false" ]; then
    CURRENT_VERSION=$(sudo systemctl status $QUIL_SERVICE_NAME@main --no-pager | grep -oP "\-([0-9]+\.)+([0-9]+)\-" | head -n 1 | tr -d 'node-')
else
    CORE_INDEX_START=$(yq '.settings.linked_node.start_cpu_index' $QTOOLS_CONFIG_FILE)
    CURRENT_VERSION=$(sudo systemctl status $QUIL_SERVICE_NAME@$CORE_INDEX_START --no-pager | grep -oP "\-([0-9]+\.)+([0-9]+)\-" | head -n 1 | tr -d 'node-')
fi
set_current_version $CURRENT_VERSION
echo $CURRENT_VERSION