#!/bin/bash

echo "Checking network connectivity..."

# Function to run a test and report its status
run_test() {
    local test_name="$1"
    local test_command="$2"
    echo -n "  $test_name: "
    if eval "$test_command"; then
        echo "PASS"
    else
        echo "FAIL"
        echo "ERROR: $test_name failed" >&2
        return 1
    fi
}

# DNS resolution test
run_test "DNS resolution" "host releases.quilibrium.com > /dev/null 2>&1"

# HTTPS connectivity test
run_test "HTTPS connectivity" "curl -s -o /dev/null -w '%{http_code}' https://releases.quilibrium.com | grep -q 200"

# Ping tests
run_test "Ping to 1.1.1.1" "ping -c 3 1.1.1.1 > /dev/null 2>&1"
run_test "Ping to 8.8.8.8" "ping -c 3 8.8.8.8 > /dev/null 2>&1"

# Check for packet loss
packet_loss=$(ping -c 10 8.8.8.8 | grep 'packet loss' | awk '{print $6}')
echo "  Packet loss to 8.8.8.8: $packet_loss"
if [[ ${packet_loss%\%} -gt 10 ]]; then
    echo "ERROR: High packet loss detected (${packet_loss})" >&2
fi

# Check average latency
avg_latency=$(ping -c 5 8.8.8.8 | tail -1 | awk '{print $4}' | cut -d '/' -f 2)
echo "  Average latency to 8.8.8.8: ${avg_latency}ms"
if (( $(echo "$avg_latency > 100" | bc -l) )); then
    echo "ERROR: High latency detected (${avg_latency}ms)" >&2
fi

# Check for available network interfaces
echo "  Available network interfaces:"
ip -br addr show | awk '{print "    - " $1 ": " $3}'

echo "Network connectivity check completed."