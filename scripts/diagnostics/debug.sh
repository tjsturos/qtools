#!/bin/bash

qtools stop
qtools update-service
sudo systemctl start $QUIL_DEBUG_SERVICE_NAME

qtools view-log

