#!/bin/bash
log "Updating node..."
cd $QUIL_PATH

# Fetch the latest changes from the remote repository
git fetch origin 

# Make sure we are using the release branch
git checkout release

# Check if there are any new commits on the remote release branch
LOCAL=$(git rev-parse release)
REMOTE=$(git rev-parse origin/release)
if [ $LOCAL != $REMOTE ]; then  
    qtools stop
    log "The 'release' branch has been updated. Pulling changes and restarting service..."
    
    # Pull the latest changes from the remote repository
    git pull &> /dev/null
    
    qtools update-service

    qtools start
    log "Updates applied and service restarted."
else
    log "Release branch is up-to-date. No restart required."
fi

log "Node update is complete."
