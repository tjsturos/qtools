#!/bin/bash

STORED_PATH="$(cat ~/saved-path)"
PATH=$STORED_PATH
log "Loading stored path: $STORED_PATH"

cd ~/ceremonyclient

version_gt() {
    test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1";
}

REMOTE_VERSION=$(git -c 'versionsort.suffix=-' \
    ls-remote --exit-code --refs --sort='version:refname' --tags <repository> '*.*.*' \
    | tail --lines=1 \
    | cut --delimiter='/' --fields=3  | cut -b 2-7)

CURRENT_VERSION=$(git tag --sort=committerdate | grep -E '[0-9]' | tail -1 | cut -b 2-7)

# only run update commands if the remote version is newer than local
if version_gt "$REMOTE_VERSION" "$CURRENT_VERSION"; then
    systemctl stop ceremonyclient.service
    git fetch origin
    git merge origin
    cd node
    GOEXPERIMENT=arenas go clean -v -n -a ./...

    remove_file $QUIL_GO_NODE_BIN

    qtools install-node-binary

    file_exists $QUIL_GO_NODE_BIN

    qtools install-qclient-binary

    systemctl start ceremonyclient.service
else
    echo "No new Quilibrium version found: $REMOTE_VERSION vs. $CURRENT_VERSION"
fi
