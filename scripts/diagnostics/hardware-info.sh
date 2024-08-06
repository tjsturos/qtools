#!/bin/bash

get_vendor() {
    cat /proc/cpuinfo | grep vendor_id | awk '{print $3}' | uniq
}

get_threads() {
    lscpu | grep 'CPU(s):' -m1 | awk '{print $2}'
}

get_cores() {
    echo "$(($(lscpu | awk '/^Socket\(s\)/{ print $2 }') * $(lscpu | awk '/^Core\(s\) per socket/{ print $4 }')))"
}

get_is_hyperthreading_enabled() {
    THREAD_COUNT=$(get_threads)
    CORES=$(get_cores)
    if [ "$THREAD_COUNT" -gt $CORES ]; then
        echo "true"
    else
        echo "false"
    fi
}

get_model_name() {
    cat /proc/cpuinfo | grep "model name" | awk -F: '{print $2}' | sed 's/^ *//g' | uniq
}

print_hardware_info() {
    echo "Vendor|$(get_vendor)"
    echo "Model|$(get_model_name)"
    echo "Cores|$(get_cores)"
    echo "Threads|$(get_threads)"
    echo "Hyperthreading Enabled|$(get_is_hyperthreading_enabled)"
}

print_hardware_info