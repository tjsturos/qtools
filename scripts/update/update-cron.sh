#!/bin/bash
# HELP: Updates the cron job for the node

# Pass all command-line arguments to qtools install-cron
qtools --describe "update-cron" install-cron "$@"
