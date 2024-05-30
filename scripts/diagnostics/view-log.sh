#!/bin/bash

sudo journalctl -u $QUIL_SERVICE_NAME -f --no-hostname -o cat
