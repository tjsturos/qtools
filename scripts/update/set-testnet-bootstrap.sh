
TESTNET_BOOTSTRAP_PEER="/ip4/91.242.214.79/udp/8336/quic-v1/p2p/QmNSGavG2DfJwGpHmzKjVmTD6CVSyJsUFTXsW4JXt2eySR"

if check_yq; then
    yq -i '.p2p.bootstrapPeers = []' $QUIL_CONFIG_FILE
    yq -i ".p2p.bootstrapPeers += \"$TESTNET_BOOTSTRAP_PEER\"" $QUIL_CONFIG_FILE
fi
