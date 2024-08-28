#!/bin/bash

# HELP: Views the logs for the node application.


sudo journalctl -u $QUIL_SERVICE_NAME -f --no-hostname -o cat
