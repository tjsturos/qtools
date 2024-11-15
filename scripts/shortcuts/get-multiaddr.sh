

PUBLIC_IP=$(curl https://ipecho.net/plain ; echo)
LISTEN_MODE=$(yq eval '.settings.listenAddr.mode' $QTOOLS_CONFIG_FILE)
LISTEN_PORT=$(yq eval '.settings.listenAddr.port // "8336"' $QTOOLS_CONFIG_FILE)
PEER_ID=$(qtools peer-id)
PROTOCOL=""
if [ "$LISTEN_MODE" = "udp" ]; then
    PROTOCOL="/quic-v1"
fi

echo "/ip4/${PUBLIC_IP}/${LISTEN_MODE}/${LISTEN_PORT}${PROTOCOL}/p2p/${PEER_ID}"
