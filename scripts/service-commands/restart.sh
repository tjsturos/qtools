#!/bin/bash

# HELP: Stops and then starts the node application service, effectively a restart.
# Usage: qtools restart

sudo systemctl restart $QUIL_SERVICE_NAME