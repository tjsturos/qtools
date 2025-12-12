#!/bin/bash
# Test script to verify QTOOLS_DESCRIBE inheritance
qtools config set-value test.inherit_test "test-value" --quiet
echo "QTOOLS_DESCRIBE in script: $QTOOLS_DESCRIBE"
