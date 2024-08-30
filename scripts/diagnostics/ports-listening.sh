#!/bin/bash
# HELP: Looks at listening ports on this machine and determines if 22, 8336, or 8337 is listening.

install_package net-tools netstat

PORTS_LISTENING="$(sudo lsof -i -P -n | grep LISTEN)"

find_port() {
    local PORT="$1"
    local DETECT_PORT_LISTENING="$(echo $PORTS_LISTENING | grep $PORT)"

    if [ -z "$DETECT_PORT_LISTENING" ]; then
        if [ "${PORT}" == "8337" ]; then
            # determine app status-- if the app hasn't reached a certain point yet, then it won't be listening
            # on port 8337 yet, so saying it wasn't found listening is not very helpful.
            IS_APP_FINISHED_STARTING="$(is_app_finished_starting)"
            UPTIME="$(get_last_started_at)"
            local streaming_text=$(sudo journalctl -u $QUIL_SERVICE_NAME@main --no-hostname -S "${UPTIME}" | grep 'begin streaming')
            if [ $IS_APP_FINISHED_STARTING == "false" ]; then
                echo "App is still starting up, port 8337 will not be ready yet."
            elif [ -z "$streaming_text" ]; then
                echo "Port $PORT not found listening. App has started. There is a misconfiguration in your Quil Node Config file."
            else
                echo "Port $PORT was found listening."
            fi
        else
            echo "Port $PORT not found listening."
        fi
    else
         echo "Port $PORT was found listening."
    fi
}

find_port 22
find_port 8336
find_port 8337
# find_port 443

