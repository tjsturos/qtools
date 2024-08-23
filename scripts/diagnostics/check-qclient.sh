#!/bin/bash

echo "Checking qclient..."

# Function to check if qclient exists and is executable
check_qclient() {
    [ -x "$QUIL_QCLIENT_BIN" ]
}

# Check for qclient
if ! check_qclient; then
    echo "ERROR: qclient is missing or not executable." >&2
    echo "Attempting to install qclient..."
    
    if qtools install-qclient; then
        echo "qclient installation completed. Verifying..."
        if check_qclient; then
            echo "qclient successfully installed and is executable."
        else
            echo "ERROR: qclient is still missing or not executable after installation attempt." >&2
            exit 1
        fi
    else
        echo "ERROR: Failed to install qclient." >&2
        exit 1
    fi
else
    echo "qclient is present and executable."
fi

# Check qclient version
if check_qclient; then
    qclient_version=$($QUIL_QCLIENT_BIN --version 2>&1)
    echo "qclient version: $qclient_version"
else
    echo "ERROR: Unable to check qclient version." >&2
 