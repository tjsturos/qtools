
#!/bin/bash

# HELP: Get token information
# PARAM: --skip-sig-check: Skip signature check (optional)

# Parse command line arguments
SKIP_SIG_CHECK=false
TOKEN=""
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --token)
        TOKEN="$2"
        shift
        shift
        ;;
        --skip-sig-check)
        SKIP_SIG_CHECK=true
        shift
        ;;
        *)
        # Unknown option
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
done

# Construct the command
CMD="$LINKED_QCLIENT_BINARY token coins"

# Add signature check flag if needed
if [ "$SKIP_SIG_CHECK" = true ]; then
    CMD="$CMD --signature-check=false"
fi

# Execute the command
TOKEN_OUTPUT=$($CMD)

if [ -z "$TOKEN" ]; then
    echo "$TOKEN_OUTPUT"
else
    echo "$TOKEN_OUTPUT" | grep "$TOKEN"
fi
