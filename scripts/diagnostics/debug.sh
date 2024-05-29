#!/bin/bash

sudo systemctl stop $QUIL_SERVICE_NAME
sudo systemctl start $QUIL_DEBUG_SERVICE_NAME

qtools view-log

