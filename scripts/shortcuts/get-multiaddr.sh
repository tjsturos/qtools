

PUBLIC_IP=""
INTERNAL_IP="${1}"

CURRENT_LISTEN_SETTINGS=$(yq eval '.p2p.listenMultiaddr' $QUIL_CONFIG_FILE)
LISTEN_MODE=$(echo $CURRENT_LISTEN_SETTINGS | sed -n 's/.*\/ip4\/\([0-9\.]\+\)\/\([a-z]\+\)\/\([0-9]\+\).*/\2/p')
LISTEN_PORT=$(echo $CURRENT_LISTEN_SETTINGS | sed -n 's/.*\/ip4\/\([0-9\.]\+\)\/\([a-z]\+\)\/\([0-9]\+\).*/\3/p')
PEER_ID=$(qtools peer-id)

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --internal)
            INTERNAL_IP=$(yq eval '.settings.internal_ip' $QTOOLS_CONFIG_FILE)
            shift
            ;;
        *)
            shift
            ;;
    esac
done

PROTOCOL=""
if [ "$LISTEN_MODE" = "udp" ]; then
    PROTOCOL="/quic-v1"
fi

if [ "$INTERNAL_IP" != "" ]; then
    echo "/ip4/${INTERNAL_IP}/${LISTEN_MODE}/${LISTEN_PORT}${PROTOCOL}/p2p/${PEER_ID}"
else
    PUBLIC_IP=$(wget -qO- https://ipecho.net/plain ; echo)
    echo "/ip4/${PUBLIC_IP}/${LISTEN_MODE}/${LISTEN_PORT}${PROTOCOL}/p2p/${PEER_ID}"
fi
