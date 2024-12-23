CURRENT_STATE=$(yq eval '.engine.createDynamicProof' $QTOOLS_CONFIG_FILE)

MANUAL_STATE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --on)
            MANUAL_STATE="true"
            shift
            ;;
        --off)
            MANUAL_STATE="false" 
            shift
            ;;
        *)
            shift
            ;;
    esac
done

enable_dynamic_proofs() {
    echo "Enabling dynamic proofs"
    yq eval -i '.engine.createDynamicProof = true' $QTOOLS_CONFIG_FILE
}

disable_dynamic_proofs() {
    echo "Disabling dynamic proofs"
    yq eval -i '.engine.createDynamicProof = false' $QTOOLS_CONFIG_FILE
}

if [ "$MANUAL_STATE" == "true" ]; then        
    enable_dynamic_proofs
elif [ "$MANUAL_STATE" == "false" ]; then
    disable_dynamic_proofs
elif [ "$CURRENT_STATE" != "true" ]; then
    enable_dynamic_proofs
else
    disable_dynamic_proofs
fi
