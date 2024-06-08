#!/bin/bash
# prints out balance in QUILs
input="$($QUIL_BIN -balance)"

unclaimed_balance=$(echo "$input" | grep "Unclaimed balance" | awk -F ": " '{print $2}' | awk '{print $1}')

echo "$unclaimed_balance"
