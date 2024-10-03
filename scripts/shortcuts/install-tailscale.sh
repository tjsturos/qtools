TAILSCALE_AUTH_KEY="$(yq -r '.settings.install.tailscale.ephemeral_key' $QTOOLS_PATH/config.yml)"

IS_INSTALL="true"

# Loop through command-line parameters
for param in "$@"; do
    case $param in
        --uninstall)
            IS_INSTALL="false"
            break
            ;;
    esac
done

if [ "$IS_INSTALL" = "false" ]; then
    log "Uninstalling Tailscale..."
    sudo tailscale down
    sudo apt-get remove tailscale -y
    exit 0
fi

log "Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh

if [ -z "$TAILSCALE_AUTH_KEY" ]; then
    log "No Tailscale auth key found, skipping automatic Tailscale auth"
    sudo tailscale up
else
    sudo tailscale up --auth-key $TAILSCALE_AUTH_KEY
fi

