cd $QUIL_NODE_PATH

OUTPUT="$($LINKED_NODE_BINARY --node-info)"

SENIORITY="$(echo "$OUTPUT" | grep -oP 'Seniority: \K.*')"

if [ -n "$SENIORITY" ]; then
    echo "$SENIORITY"
else
    log "Could not find seniority."
fi
 
