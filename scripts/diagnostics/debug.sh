#!/bin/bash

qtools stop

sudo systemctl start $QUIL_DEBUG_SERVICE_NAME

qtools view-log

