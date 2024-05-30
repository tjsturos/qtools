#!/bin/bash

if [ -d "$QUIL_PATH" ]; then
    cd $QUIL_PATH
    git remote set-url origin $SOURCE_URL
else
    log "No directory "$QUIL_PATH" exists."
    exit 1
fi
