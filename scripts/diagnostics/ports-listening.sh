#!/bin/bash
# HELP: Looks at listening ports on this machine and determines if 22, 8336, or 8337 is listening.

install_package net-tools netstat

if [ "$IS_APP_FINISHED_STARTING" != "true" ]; then
    echo "App is still starting. Some ports may not be ready yet."
fi

PORTS_LISTENING="$(sudo lsof -i -P -n | grep LISTEN)"

find_port() {
    local PORT="$1"
    local DETECT_PORT_LISTENING="$(echo $PORTS_LISTENING | grep $PORT)"

    if [ -z "$DETECT_PORT_LISTENING" ]; then
        if [ "${PORT}" == "8337" ] && [ "$IS_APP_FINISHED_STARTING" != "true" ]; then
            echo "App is still starting up, port 8337 will not be ready yet."
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

