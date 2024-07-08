#!/bin/bash
IS_LINKED="$(yq '.settings.linked_node.enabled' $QTOOLS_CONFIG_FILE)"

if [ "$IS_LINKED" == "false" ]; then
    local CURRENT_VERSION=$(systemctl status $QUIL_SERVICE_NAME@main | grep -oP "\-([0-9]+\.)+([0-9]+)\-" | head -n 1 | tr -d 'node-')
else
    local CORE_INDEX_START=$(yq '.settings.linked_node.start_cpu_index' $QTOOLS_CONFIG_FILE)
    local CURRENT_VERSION=$(systemctl status $QUIL_SERVICE_NAME@$CORE_INDEX_START | grep -oP "\-([0-9]+\.)+([0-9]+)\-" | head -n 1 | tr -d 'node-')
fi
set_current_version $CURRENT_VERSION
echo $CURRENT_VERSION
echo ""