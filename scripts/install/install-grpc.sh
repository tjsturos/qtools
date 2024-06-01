#!/bin/bash
log "Installing grpcurl..."

go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest &> /dev/null

if command_exists grpcurl; then
    log "Successfully install grpcurl."
else
    log "Failed to install grpcurl."
fi


