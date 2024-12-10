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

get_ram() {
    free -h | awk '/^Mem:/ {print $2}'
}

get_hdd_space() {
    df -h / | awk 'NR==2 {print $2}'
}

get_memory_percentage() {
    local total_memory=$(free | grep Mem | awk '{print $2}')
    local used_memory=$(free | grep Mem | awk '{print $3}')
    echo "($used_memory * 100) / $total_memory" | bc
}