#!/bin/bash
# HELP: Installs the necessary packages for grpcurl, which is used for some node commands.

log "Installing grpcurl..." 

if ! command_exists go; then
    log "Go binary not found, going to install go..."
    qtools install-go
fi

go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest &> /dev/null

if command_exists grpcurl; then
    log "Successfully install grpcurl."
else
    log "Failed to install grpcurl."
fi


