#!/bin/bash
# HELP: Enables the node application service, allowing it to start on system boot. Note: this does not start the node service immediately.

# Usage: qtools enable

sudo systemctl enable $QUIL_SERVICE_NAME@main.service
