cd $QUIL_NODE_PATH

OUTPUT="$($LINKED_NODE_BINARY --node-info)"

BALANCE="$(echo "$OUTPUT" | grep -oP 'Owned balance: \K.*')"

if [ -n "$BALANCE" ]; then
    echo "$BALANCE"
else
    log "Could not find Peer ID."
fi
 
