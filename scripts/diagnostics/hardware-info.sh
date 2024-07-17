#!/bin/bash
INFO_ICON="\u2139"  # Info Icon

get_vendor() {
    cat /proc/cpuinfo | grep vendor_id | awk '{print $3}' | uniq
}

get_threads() {
    cat /proc/cpuinfo | grep siblings | awk '{print $3}' | uniq
}

get_is_hyperthreading_enabled() {
    CORE_COUNT=$(cat /proc/cpuinfo | grep "cpu cores" | awk '{print $4}' | uniq)
    SIBLINGS=$(cat /proc/cpuinfo | grep siblings | awk '{print $3}' | uniq)
    if [ "$SIBLINGS" -gt "$CORE_COUNT" ]; then
        echo "true"
    else
        echo "false"
    fi
}

get_model_name() {
    cat /proc/cpuinfo | grep "model name" | awk -F: '{print $2}' | sed 's/^ *//g' | uniq
}


echo -e "${INFO_ICON} Vendor: $(get_vendor)"
echo -e "${INFO_ICON} Threads: $(get_threads)"
echo -e "${INFO_ICON} Hyperthreading Enabled: $(get_is_hyperthreading_enabled)"
echo -e "${INFO_ICON} Model: $(get_model_name)"
