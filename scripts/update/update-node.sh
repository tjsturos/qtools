#!/bin/bash
cd $QUIL_PATH

#!/bin/bash

# Fetch the latest changes from the remote repository
git fetch origin

# Check if there are any new commits on the remote release branch
LOCAL=$(git rev-parse release)
REMOTE=$(git rev-parse origin/release)

git checkout release
if [ $LOCAL != $REMOTE ]; then
    echo "Release branch has been updated. Pulling changes and restarting service."
    
    # Pull the latest changes from the remote repository
    git pull
    
    # Start qtools
    qtools start
    
    # Force a restart
    qtools restart
else
    echo "Release branch is up-to-date. No restart required."
    

    # Start qtools without restart
    qtools start
fi