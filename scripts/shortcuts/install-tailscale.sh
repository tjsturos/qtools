TAILSCALE_AUTH_KEY="$(yq -r '.settings.install.tailscale.ephemeral_key' $QTOOLS_PATH/config.yml)"


curl -fsSL https://tailscale.com/install.sh | sh

if [ -z "$TAILSCALE_AUTH_KEY" ]; then
    log "No Tailscale auth key found, skipping automatic Tailscale auth"
    sudo tailscale up
else
    sudo tailscale up --auth-key $TAILSCALE_AUTH_KEY
fi
