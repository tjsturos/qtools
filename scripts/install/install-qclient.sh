#!/bin/bash
# HELP: Installs the latest qclient from the CDN.

CURRENT_QCLIENT_BINARY="$(get_versioned_qclient)"

if [ ! -f "$QUIL_CLIENT_PATH/$CURRENT_QCLIENT_BINARY" ]; then
    qclient_files=$(fetch_available_files "https://releases.quilibrium.com/qclient-release")

    sudo mkdir -p $QUIL_CLIENT_PATH

    # Ensure quilibrium user has access if using quilibrium user
    SERVICE_USER=$(yq '.service.default_user // "quilibrium"' $QTOOLS_CONFIG_FILE 2>/dev/null || echo "quilibrium")
    if [ "$SERVICE_USER" == "quilibrium" ] && id "quilibrium" &>/dev/null; then
        sudo chown -R quilibrium:$QTOOLS_GROUP "$QUIL_CLIENT_PATH" 2>/dev/null || true
        # Ensure qtools group can read, write, and execute
        sudo chmod -R g+rwx "$QUIL_CLIENT_PATH" 2>/dev/null || true
    fi

    get_remote_quil_files qclient_files[@] $QUIL_CLIENT_PATH

    if [ -f $QUIL_CLIENT_PATH/$CURRENT_QCLIENT_BINARY ]; then
        sudo chmod +x $QUIL_CLIENT_PATH/$CURRENT_QCLIENT_BINARY

        # Ensure quilibrium user owns the binary if using quilibrium user
        if [ "$SERVICE_USER" == "quilibrium" ] && id "quilibrium" &>/dev/null; then
            sudo chown quilibrium:$QTOOLS_GROUP "$QUIL_CLIENT_PATH/$CURRENT_QCLIENT_BINARY" 2>/dev/null || true
            sudo chmod g+rwx "$QUIL_CLIENT_PATH/$CURRENT_QCLIENT_BINARY" 2>/dev/null || true
        fi

        if [ -s $QUIL_QCLIENT_BIN ]; then
            rm $QUIL_QCLIENT_BIN
        fi

        sudo ln -s $QUIL_CLIENT_PATH/$CURRENT_QCLIENT_BINARY $QUIL_QCLIENT_BIN
    fi
fi