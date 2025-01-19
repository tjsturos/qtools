#!/bin/bash
# HELP: Toggles automatic config carousel on or off using systemd service
# PARAM: --on: Explicitly turn config carousel on
# PARAM: --off: Explicitly turn config carousel off
# PARAM: --frames: Number of frames to wait before switching (default: 10)
# PARAM: --restart: Restart the service if it's running
# Usage: qtools toggle-config-carousel [--on|--off] [--frames <num-frames>] [--restart]

# Check if config needs migration
if ! yq eval '.scheduled_tasks.config_carousel' $QTOOLS_CONFIG_FILE >/dev/null 2>&1; then
    echo "Config needs migration. Running migration..."
    qtools migrate-qtools-config
fi

FRAMES=10
RESTART=false

# Function to set switch configs status
set_switch_configs_status() {
    local status=$1
    yq -i ".scheduled_tasks.config_carousel.enabled = $status" $QTOOLS_CONFIG_FILE
    yq -i ".scheduled_tasks.config_carousel.frames = $FRAMES" $QTOOLS_CONFIG_FILE
}

# Function to manage systemd service
manage_service() {
    local action=$1
    local service_name="quil-config-carousel.service"
    local service_path="/etc/systemd/system/$service_name"
    
    if [ "$action" = "start" ]; then
        # Create service content
        local SERVICE_CONTENT="[Unit]
Description=Quilibrium Config Carousel Service
After=network.target

[Service]
Type=simple
User=$USER
Environment=QTOOLS_CONFIG_FILE=$HOME/.qtools/config.yml
Environment=QUIL_NODE_PATH=$HOME/ceremonyclient/node
ExecStart=/usr/local/bin/qtools config-carousel --daemon --frames $FRAMES
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target"

        # Write service file
        echo "$SERVICE_CONTENT" | sudo tee "$service_path" > /dev/null
        sudo systemctl daemon-reload
        
        sudo systemctl enable "$service_name"
        sudo systemctl start "$service_name"
        echo "Config switching service started"
    elif [ "$action" = "restart" ]; then
        if sudo systemctl is-active "$service_name" >/dev/null 2>&1; then
            echo "Restarting config switching service..."
            local SERVICE_CONTENT="[Unit]
Description=Quilibrium Config Carousel Service
After=network.target

[Service]
Type=simple
User=$USER
Environment=QTOOLS_CONFIG_FILE=$HOME/.qtools/config.yml
Environment=QUIL_NODE_PATH=$HOME/ceremonyclient/node
ExecStart=/usr/local/bin/qtools config-carousel --daemon --frames $FRAMES
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target"

        # Write service file
        echo "$SERVICE_CONTENT" | sudo tee "$service_path" > /dev/null
            sudo systemctl daemon-reload
            sudo systemctl restart "$service_name"
            echo "Config switching service restarted"
        else
            echo "Config switching service is not running"
        fi
    else
        sudo systemctl stop "$service_name"
        sudo systemctl disable "$service_name"
        [ -f "$service_path" ] && sudo rm "$service_path"
        sudo systemctl daemon-reload
        echo "Config switching service stopped"
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --on|--off)
            ACTION=${1#--}
            shift
            ;;
        --frames)
            FRAMES="$2"
            shift 2
            ;;
        --restart)
            RESTART=true
            shift
            ;;
        *)
            echo "Invalid argument. Use --on or --off to set status, --restart to restart service, and optionally --frames <num>"
            exit 1
            ;;
    esac
done

# Handle restart flag first if specified
if [ "$RESTART" = true ]; then
    manage_service restart
    exit 0
fi

# Get current status
current_status=$(yq '.scheduled_tasks.config_carousel.enabled // false' $QTOOLS_CONFIG_FILE)

# Handle explicit on/off or toggle
if [ -n "$ACTION" ]; then
    if [ "$ACTION" = "on" ]; then
        if [ "$current_status" = "true" ]; then
            echo "Config switching is already enabled."
            exit 0
        fi
        set_switch_configs_status true
        manage_service start
    else
        if [ "$current_status" = "false" ]; then
            echo "Config switching is already disabled."
            exit 0
        fi
        set_switch_configs_status false
        manage_service stop
    fi
else
    # Toggle current status
    if [ "$current_status" = "true" ]; then
        set_switch_configs_status false
        manage_service stop
    else
        set_switch_configs_status true
        manage_service start
    fi
fi 