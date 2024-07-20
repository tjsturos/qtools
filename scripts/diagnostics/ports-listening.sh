#!/bin/bash
# HELP: Looks at listening ports on this machine and determines if 22, 8336, or 8337 is listening.

install_package net-tools netstat

PORTS_LISTENING="$(sudo netstat -lntup)"

find_port() {
    local PORT="$1"
    local DETECT_PORT_LISTENING="$(echo $PORTS_LISTENING | grep $PORT)"

    if [ -z "$DETECT_PORT_LISTENING" ]; then
        if [ "${PORT}" == "8337" ]; then
            # determine app status-- if the app hasn't reached a certain point yet, then it won't be listening
            # on port 8337 yet, so saying it wasn't found listening is not very helpful.
            local uptime=$(echo "qtools status" | grep -oP '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}' -m1)
            local streaming_text="$(sudo journalctl -u ceremonyclient@main --no-hostname -S \"$date_time\" | grep 'begin streaming')"
            local app_text="$(sudo journalctl -u ceremonyclient@main --no-hostname -S \"$date_time\" | grep 'peers in store')"
            if [ -z "$streaming_text" ] && [ -z "$app_text"]; then
                echo "App is still starting up, port 8337 will not be ready yet."
            elif [ ! -z "$app_text" ] && [ -z "$streaming_text" ]; then
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

