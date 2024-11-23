OUTPUT="$(run_node_command --prover-ring)"

PROVER_RING="$(echo "$OUTPUT" | grep -oP 'Prover Ring: \K.*')"

if [ -n "$PROVER_RING" ]; then
    echo "$PROVER_RING"
else
    log "Could not find prover ring."
fi
 
