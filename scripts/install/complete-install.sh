#/bin/bash
# HELP: Runs a complete install of the node.
# USAGE: qtools complete-install [--peer-id <peer_id>]
#
# Options:
#   --peer-id <peer_id>    Specify a custom peer ID for the node. If not provided,
#                          a new peer ID will be generated automatically.
#
# This script performs a complete installation of the Quilibrium node.
# If a peer ID is provided, it will be used for the node configuration and backups.
# Otherwise, a new peer ID will be generated during the installation process.


sudo apt-get -q update

# Parse command line arguments
PEER_ID=""
RESTORE=false
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --peer-id)
        PEER_ID="$2"
        shift # past argument
        shift # past value
        ;;
        --restore)
        RESTORE=true
        shift # past argument
        ;;
        *)    # unknown option
        shift # past argument
        ;;
    esac
done


DISABLE_SSH_PASSWORDS="$(yq '.settings.install.ssh.disable_password_login // "false"') $QTOOLS_CONFIG_FILE"

cd $QUIL_HOME

# Initialize hooks first so node.real symlink exists
source $QTOOLS_PATH/hooks/hooks-init.sh

# Now download and link the node binary to node.real
qtools download-node --link
qtools download-qclient --link
qtools update-service

qtools install-go
qtools install-grpc
qtools setup-firewall
qtools install-cron

generate_default_config() {
    # This first command generates a default config file
    BINARY_NAME="$(get_current_versioned_node)"
    BINARY_FILE=$QUIL_NODE_PATH/$BINARY_NAME
    $BINARY_FILE -peer-id
    sleep 3
    if [ -f $BINARY_FILE ]; then 
        qtools modify-config
    fi
}

if [ "$PEER_ID" != "" ]; then
    log "Attempting to restore from remote backup. Note: backups must be enabled and configured properly (and connected to at least once) for this to work."

    if [ "$PEER_ID" != "false" ] && [ "$PEER_ID" != "" ]; then
        qtools restore-backup --peer-id $PEER_ID --force
        wait
        if [ -f $BINARY_FILE ]; then 
            qtools modify-config
        fi
    else
        log "No peer ID found, skipping restore."
        generate_default_config
    fi
else
    generate_default_config
fi


# tells server to always start node service on reboot
qtools enable

if [ "$DISABLE_SSH_PASSWORDS" == 'true' ]; then

    PUBLIC_KEY_URL="$(yq '.settings.install.ssh.public_key_url' $QTOOLS_CONFIG_FILE)"
    PUBLIC_KEY="$(yq '.settings.install.ssh.public_key_string' $QTOOLS_CONFIG_FILE)"

    # if defined, fetch remote public key
    if [ ! -z "$PUBLIC_KEY_URL" ]; then
        PUBLIC_KEY="$(dig TXT $PUBLIC_KEY_URL +short | sed -e 's/" "//g' -e 's/"//g')"
    fi

    if [ ! -z "$PUBLIC_KEY" ]; then
        qtools add-public-ssh-key "$PUBLIC_KEY"
    fi

    # Check if authorized_keys file exists and is not empty
    if [ ! -s "$HOME/.ssh/authorized_keys" ]; then
        log "No authorized keys found. Skipping SSH password disable for safety."
        exit 0
    fi

    qtools disable-ssh-passwords
fi

source $QTOOLS_PATH/scripts/install/customization.sh

