#!/bin/bash

get_vendor() {
    sysctl -n machdep.cpu.vendor
}

get_threads() {
    sysctl -n hw.logicalcpu
}

get_cores() {
    sysctl -n hw.physicalcpu
}

get_is_hyperthreading_enabled() {
    THREAD_COUNT=$(get_threads)
    CORES=$(get_cores)
    if [ "$THREAD_COUNT" -gt "$CORES" ]; then
        echo "true"
    else
        echo "false"
    fi
}

get_model_name() {
    sysctl -n machdep.cpu.brand_string
}

print_hardware_info() {
    echo "Vendor|$(get_vendor)"
    echo "Model|$(get_model_name)"
    echo "Cores|$(get_cores)"
    echo "Threads|$(get_threads)"
    echo "Hyperthreading Enabled|$(get_is_hyperthreading_enabled)"
}

print_hardware_info