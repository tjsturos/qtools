#!/bin/bash

if [ ! -d "$QUIL_CLIENT_PATH" ]; then
    wait_for_directory $QUIL_CLIENT_PATH
fi

log "Installing qClient..."
cd $QUIL_CLIENT_PATH

# Remove the file before re-installation
if [ -f "$QUIL_CLIENT_PATH/qclient" ]; then
    remove_file $QUIL_CLIENT_PATH/qclient
fi

# Install
GOEXPERIMENT=arenas go build -o /root/go/bin/qclient main.go > /dev/null 2>&1

# verify install
file_exists $QUIL_CLIENT_PATH/qclient

if [ -f  /usr/local/bin/qclient ]; then
    ln -s $QUIL_CLIENT_PATH/qclient /usr/local/bin/qclient
fi

_qclient_completions() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Define the top-level commands
    opts="token cross-mint"

    # Define subcommands for 'token'
    if [[ ${prev} == "token" ]]; then
        COMPREPLY=( $(compgen -W "balance coins transfer accept reject mutual-receive mutual-transfer mint split merge" -- ${cur}) )
        return 0
    fi

    if [[ ${prev} == "mint" ]]; then
        COMPREPLY=( $(compgen -W "all" -- ${cur}) )
        return 0
    fi

    # Provide top-level command completions
    if [[ ${COMP_CWORD} == 1 ]]; then
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
        return 0
    fi

    return 0
}

complete -F _qclient_completions qclient

source ~/.bashrc
