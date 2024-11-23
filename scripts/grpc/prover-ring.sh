cd $QUIL_NODE_PATH

SIGNATURE_CHECK=$(yq '.service.signature_check // ""' $QTOOLS_CONFIG_FILE)

OUTPUT="$($LINKED_NODE_BINARY ${SIGNATURE_CHECK:+--signature-check=false} --node-info)"

PROVER_RING="$(echo "$OUTPUT" | grep -oP 'Prover Ring: \K.*')"

if [ -n "$PROVER_RING" ]; then
    echo "$PROVER_RING"
else
    log "Could not find prover ring."
fi
 
