#!/bin/bash

if [ -d "$QUIL_PATH" ]; then
    cd $QUIL_PATH
    CURRENT_REMOTE_URL="$(git remote get-url origin)"

    if [ "$CURRENT_REMOTE_URL" != "$SOURCE_URL" ]; then
        log "Updating the git repo's source url from $CURRENT_REMOTE_URL to $SOURCE_URL."
        git remote set-url origin $SOURCE_URL

        CHANGED_REMOTE_URL="$(git remote get-url origin)"
        if [ "$CHANGED_REMOTE_URL" == "$SOURCE_URL" ]; then
            log "Successfully changed the git repo's source url to $SOURCE_URL."
        else
            log "Did not successfully change the git repo's source url ($CHANGED_REMOTE_URL)."
        fi
    fi
else
    log "No directory "$QUIL_PATH" exists. You need to modify the QUIL_PATH variable in the qtools/qtools.sh script or install the Ceremony Client"
    exit 1
fi
