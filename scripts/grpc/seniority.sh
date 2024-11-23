cd $QUIL_NODE_PATH

SIGNATURE_CHECK=$(yq '.service.signature_check // ""' $QTOOLS_CONFIG_FILE)

OUTPUT="$($LINKED_NODE_BINARY ${SIGNATURE_CHECK:+--signature-check=false} --node-info)"

SENIORITY="$(echo "$OUTPUT" | grep -oP 'Seniority: \K.*')"

if [ -n "$SENIORITY" ]; then
    echo "$SENIORITY"
else
    log "Could not find seniority."
fi
 
