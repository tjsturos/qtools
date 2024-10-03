#!/bin/bash
# HELP: Updates the Qtools suite, as well as adding auto-complete and installing any new cron tasks.

log "Starting qtools update..."
is_auto_update_enabled=$(yq '.settings.auto_updates.qtools // true' $QTOOLS_CONFIG_FILE)

auto_update="false"

for param in "$@"; do
    case $param in
        --auto)
            auto_update="true"
            ;;
        *)
            echo "Unknown parameter: $param"
            exit 1
            ;;
    esac
done

main() {
    cd $QTOOLS_PATH
    git pull &> /dev/null
    log "Changes fetched."
    qtools add-auto-complete
    qtools install-cron
}

if [ "$auto_update" == "true" ] && [ "$is_auto_update_enabled" == "false" ]; then
  log "Qtools auto-update is disabled. Exiting."
  exit 0
fi

main
source ~/.bashrc

log "Finished qtools update."

