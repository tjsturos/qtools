OUTPUT="$(run_node_command --node-info "$@")"

SENIORITY="$(echo "$OUTPUT" | grep -oP 'Seniority: \K.*')"

if [ -n "$SENIORITY" ]; then
    echo "$SENIORITY"
else
    log "Could not find seniority."
fi
 
