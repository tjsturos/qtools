#!/bin/bash

get_vendor() {
    echo "Apple"
}

get_threads() {
    sysctl -n hw.logicalcpu
}

get_cores() {
    sysctl -n hw.physicalcpu
}

get_memory() {
    sysctl -n hw.memsize
}

get_model_name() {
    MODEL=$(sysctl -n machdep.cpu.brand_string)
    echo "${MODEL#Apple }"
}

print_hardware_info() {
    echo "Vendor: $(get_vendor)"
    echo "Model: $(get_model_name)"
    echo "Cores: $(get_cores)"
    echo "Threads: $(get_threads)"
    echo "Memory: $(get_memory)"
}

print_hardware_info