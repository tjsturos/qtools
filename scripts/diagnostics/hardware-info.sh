#!/bin/bash

# Parse command line args
SINGLE_LINE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--single-line)
            SINGLE_LINE=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done



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


print_hardware_info_single_line() {
    HT_STATUS=$(get_is_hyperthreading_enabled)
    if [ "$HT_STATUS" = "true" ]; then
        HT="HT-on"
    else
        HT="HT-off"
    fi
    echo "$(get_vendor)/$(get_model_name)/phys-cores:$(get_cores)/nproc:$(get_threads)/$HT"
}

if [ "$SINGLE_LINE" = true ]; then
    print_hardware_info_single_line
    exit 0
fi

print_hardware_info