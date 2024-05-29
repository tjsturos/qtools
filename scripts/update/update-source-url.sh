#!/bin/bash
GIT_SOURCE="${1:-$SOURCE_URL}"

if [ -d "$QUIL_PATH" ]; then
    cd $QUIL_PATH
    git remote set-url origin $GIT_SOURCE
else
    log "No directory "$QUIL_PATH" exists."
    exit 1
fi
