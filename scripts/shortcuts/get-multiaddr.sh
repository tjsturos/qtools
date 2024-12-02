

PUBLIC_IP=$(wget -qO- https://ipecho.net/plain ; echo)
CURRENT_LISTEN_SETTINGS=$(yq eval '.p2p.listenMultiaddr' $QUIL_CONFIG_FILE)
LISTEN_MODE=$(echo $CURRENT_LISTEN_SETTINGS | sed -n 's/.*\/ip4\/\([0-9\.]\+\)\/\([a-z]\+\)\/\([0-9]\+\).*/\2/p')
LISTEN_PORT=$(echo $CURRENT_LISTEN_SETTINGS | sed -n 's/.*\/ip4\/\([0-9\.]\+\)\/\([a-z]\+\)\/\([0-9]\+\).*/\3/p')
PEER_ID=$(qtools peer-id "$@")
PROTOCOL=""
if [ "$LISTEN_MODE" = "udp" ]; then
    PROTOCOL="/quic-v1"
fi

echo "/ip4/${PUBLIC_IP}/${LISTEN_MODE}/${LISTEN_PORT}${PROTOCOL}/p2p/${PEER_ID}"
