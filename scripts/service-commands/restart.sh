#!/bin/bash

# HELP: Stops and then starts the node application service, effectively a restart.  Calls \'qtools stop\' and then \'qtools start\'.
# PARAM: --debug: will restart the node in debug mode
# PARAM: --quick: will restart the node without disabling/renabling qtools services
# Usage: qtools restart
# Usage: qtools restart --debug
# Usage: qtools restart --quick
# Usage: qtools restart --debug --quick

PARAMS=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --debug)
            PARAMS="$PARAMS --debug"
            shift
            ;;
        --quick)
            PARAMS="$PARAMS --quick"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Trim leading whitespace from PARAMS
PARAMS="${PARAMS## }"

qtools stop $PARAMS
qtools start $PARAMS