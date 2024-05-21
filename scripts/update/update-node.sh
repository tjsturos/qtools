#!/bin/bash
cd $QUIL_PATH

CURRENT_VERSION=$(git tag --sort=committerdate | grep -E '[0-9]' | tail -1 | cut -b 2-7)

# only run update commands if the remote version is newer than local
if [ "$(git rev-list HEAD..origin/main --count)" -gt 0 ]; then
    systemctl stop ceremonyclient.service
    git fetch origin
    git merge origin
    cd node
    GOEXPERIMENT=arenas go clean -v -n -a ./...

    # Install binaries
    qtools install-node-binary
    qtools install-qclient-binary

    systemctl start ceremonyclient.service
    NEW_VERSION=$(git tag --sort=committerdate | grep -E '[0-9]' | tail -1 | cut -b 2-7)
    log "Installing new version: $CURRENT_VERSION->$NEW_VERSION"
else
    log "No new Quilibrium version found (existing: $CURRENT_VERSION)"
fi
