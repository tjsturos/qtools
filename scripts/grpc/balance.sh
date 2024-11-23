
OUTPUT="$(run_node_command --node-info "$@")"

BALANCE="$(echo "$OUTPUT" | grep -oP 'Owned balance: \K.*')"

if [ -n "$BALANCE" ]; then
    echo "$BALANCE"
else
    log "Could not find Peer ID."
fi
 
