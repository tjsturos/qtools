#!/bin/bash

sudo journalctl -u $QUIL_DEBUG_SERVICE_NAME -f --no-hostname -o cat
