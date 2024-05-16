#!/bin/bash
log "installing go"
wget  https://go.dev/dl/go1.20.14.linux-amd64.tar.gz
tar -xvf go1.20.14.linux-amd64.tar.gz
mv  go  /usr/local

rm  go1.20.14.linux-amd64.tar.gz