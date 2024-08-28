#!/bin/bash

load=$(uptime | awk '{print $10}' | tr -d ',')
threshold=8.0  # Increased threshold for high load expectation

if (( $(echo "$load < $threshold" | bc -l) )); then
    echo "Unusually low CPU load detected: $load"
    return 1
else
    echo "CPU load is within expected range: $load"
    return 0
fi