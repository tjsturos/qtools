#!/bin/bash
# HELP: Gets the node application service\'s current status.
# Usage: qtools status

sudo systemctl status $QUIL_SERVICE_NAME.service --no-pager
