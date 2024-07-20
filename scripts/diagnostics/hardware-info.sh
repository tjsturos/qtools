#!/bin/bash
INFO_ICON="\u2139"  # Info Icon
BLUE='\033[0;34m'
NC='\033[0m'

get_vendor() {
    cat /proc/cpuinfo | grep vendor_id | awk '{print $3}' | uniq
}

get_threads() {
    echo $(lscpu | grep 'CPU(s):' -m1 | awk '{print $2}')
}

get_is_hyperthreading_enabled() {
    THREAD_COUNT=$(get_threads)
    SOCKETS=$(lscpu | grep "Socket(s)" -m1 | awk '{print $2}')
    if [ $THREADS_COUNT -gt $SOCKETS ]; then
        echo "\e[32mtrue\e[0m"
    else
        echo "\e[31mfalse\e[0m"
    fi
}

get_model_name() {
    cat /proc/cpuinfo | grep "model name" | awk -F: '{print $2}' | sed 's/^ *//g' | uniq
}


echo -e "${BLUE}${INFO_ICON}${NC} Vendor: $(get_vendor)"
echo -e "${BLUE}${INFO_ICON}${NC} Model: $(get_model_name)"
echo -e "${BLUE}${INFO_ICON}${NC} Threads: $(get_threads)"
echo -e "${BLUE}${INFO_ICON}${NC} Hyperthreading Enabled: $(get_is_hyperthreading_enabled)"
