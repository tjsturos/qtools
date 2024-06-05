#!/bin/bash

install_package net-tools netstat

PORTS_LISTENING="$(sudo netstat -lntup)"

find_port() {
    PORT="$1"
    DETECT_PORT_LISTENING="$(echo $PORTS_LISTENING | grep $PORT)"

    if [ -z "$DETECT_PORT_LISTENING" ]; then
        echo "Port $PORT not found listening."
    else
         echo "Port $PORT was found listening."
    fi
}

find_port 22
find_port 8336
find_port 8337
find_port 443

