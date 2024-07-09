#!/bin/bash

# HELP: Stops and then starts the node application service, effectively a restart.  Calls \'qtools stop\' and then \'qtools start\'.
# PARAM: --debug: will restart the node in debug mode
# Usage: qtools restart
# Usage: qtools restart --debug

PARAMS=""
if [ "$1" == "--debug" ]; then
    PARAMS="--debug"
fi

qtools stop
qtools start $PARAMS