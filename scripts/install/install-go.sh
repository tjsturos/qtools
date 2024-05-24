#!/bin/bash
log "installing go"
wget  https://go.dev/dl/go1.20.14.linux-amd64.tar.gz
tar -xvf go1.20.14.linux-amd64.tar.gz
mv  go  /usr/local

remove_file  go1.20.14.linux-amd64.tar.gz

BASHRC=~/.bashrc
append_to_file $BASHRC "export GOROOT=/usr/local/go"
append_to_file $BASHRC "export GOPATH=\$HOME/go"
append_to_file $BASHRC "export PATH=\$GOPATH/bin:\$GOROOT/bin:\$PATH"

source $BASHRC