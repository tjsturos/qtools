cd $QUIL_NODE_PATH

SIGNATURE_CHECK=$(yq '.service.signature_check // ""' $QTOOLS_CONFIG_FILE)

OUTPUT="$($LINKED_NODE_BINARY ${SIGNATURE_CHECK:+--signature-check=false} --node-info)"

BALANCE="$(echo "$OUTPUT" | grep -oP 'Owned balance: \K.*')"

if [ -n "$BALANCE" ]; then
    echo "$BALANCE"
else
    log "Could not find Peer ID."
fi
 
