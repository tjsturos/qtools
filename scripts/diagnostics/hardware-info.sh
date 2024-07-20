#!/bin/bash
INFO_ICON="\u2139"  # Info Icon
BLUE='\033[0;34m'
NC='\033[0m'

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
        echo "\e[32mtrue\e[0m"
    else
        echo "\e[31mfalse\e[0m"
    fi
}

get_model_name() {
    cat /proc/cpuinfo | grep "model name" | awk -F: '{print $2}' | sed 's/^ *//g' | uniq
}


echo -e "${BLUE}${INFO_ICON}${NC} Vendor: $(get_vendor)"
echo -e "${BLUE}${INFO_ICON}${NC} Threads: $(get_threads)"
echo -e "${BLUE}${INFO_ICON}${NC} Hyperthreading Enabled: $(get_is_hyperthreading_enabled)"
echo -e "${BLUE}${INFO_ICON}${NC} Model: $(get_model_name)"