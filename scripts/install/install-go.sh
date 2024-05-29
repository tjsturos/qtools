#!/bin/bash
log "Installing Go"
wget https://go.dev/dl/go1.20.14.linux-amd64.tar.gz
tar -xvf go1.20.14.linux-amd64.tar.gz
mv go /usr/local

remove_file  go1.20.14.linux-amd64.tar.gz false

append_to_file $BASHRC_FILE "export GOROOT=/usr/local/go" false
append_to_file $BASHRC_FILE "export GOPATH=$HOME/go" false
append_to_file $BASHRC_FILE "export PATH=\$GOPATH/bin:\$GOROOT/bin:\$PATH" false

source $BASHRC_FILE