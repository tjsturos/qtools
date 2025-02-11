#!/bin/bash

# Get publish multiaddr settings from config (reuse existing config)
SSH_KEY_PATH=$(yq eval '.settings.central_server.ssh_key_path' $QTOOLS_CONFIG_FILE)
REMOTE_USER=$(yq eval '.settings.central_server.remote_user' $QTOOLS_CONFIG_FILE)
REMOTE_HOST=$(yq eval '.settings.central_server.remote_host' $QTOOLS_CONFIG_FILE)
REMOTE_FILE="~/worker_availability.yml"


check_availability() {
    # Check availability status
    AVAILABLE=$(ssh -i "$SSH_KEY_PATH" "${REMOTE_USER}@${REMOTE_HOST}" "
    if [ ! -f $REMOTE_FILE ]; then
        echo 'true'
        exit 0
    fi

    yq eval '.available' $REMOTE_FILE
    ")
    echo $AVAILABLE
}

AVAILABLE=$(check_availability)
USING_WORKERS=$(yq eval '.scheduled_tasks.config_carousel.check_workers.using_workers // false' $QTOOLS_CONFIG_FILE)
echo "AVAILABLE: $AVAILABLE"
echo "USING_WORKERS: $USING_WORKERS"
if [[ "$AVAILABLE" == "true" ]]; then
    if [[ "$USING_WORKERS" == "false" ]]; then
        yq eval -i '.scheduled_tasks.config_carousel.check_workers.using_workers = true' $QTOOLS_CONFIG_FILE
        echo "Workers are available, switching to in-use config"
        IN_USE_CONFIG_FILE="$(eval echo $(yq eval '.scheduled_tasks.config_carousel.check_workers.in_use_config_file // "~/ceremonyclient/node/in-use-config.yml"' $QTOOLS_CONFIG_FILE))"
        if [ -f ${IN_USE_CONFIG_FILE} ]; then
            cp ${IN_USE_CONFIG_FILE} $QUIL_NODE_PATH/.config/config.yml
            sudo systemctl restart $QUIL_SERVICE_NAME
        else
            echo "No in-use config file found ($IN_USE_CONFIG_FILE), starting whatever is already defined"
            sudo systemctl start $QUIL_SERVICE_NAME
        fi
    else
        echo "Workers are available, but already in use, skipping"
    fi
elif [[ "$AVAILABLE" == "false" ]]; then
    if [[ "$USING_WORKERS" == "true" ]]; then
        yq eval -i '.scheduled_tasks.config_carousel.check_workers.using_workers = false' $QTOOLS_CONFIG_FILE
        echo "Workers are not available, switching to idle config"
        IDLE_CONFIG_FILE="$(eval echo $(yq eval '.scheduled_tasks.config_carousel.check_workers.idle_config_file // "~/ceremonyclient/node/idle-config.yml"' $QTOOLS_CONFIG_FILE))"
        if [ -f ${IDLE_CONFIG_FILE} ]; then
            cp ${IDLE_CONFIG_FILE} $QUIL_NODE_PATH/.config/config.yml
            sudo systemctl restart $QUIL_SERVICE_NAME
        else
            echo "No idle config file found ($IDLE_CONFIG_FILE), stopping node"
            sudo systemctl stop $QUIL_SERVICE_NAME
        fi
    else
        echo "Workers are not available, but already in idle state, skipping"
    fi
fi
