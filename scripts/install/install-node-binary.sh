#!/bin/bash

remove_file $QUIL_GO_NODE_BIN

cd $QUIL_NODE_PATH
GOEXPERIMENT=arenas go install  ./...

file_exists $QUIL_GO_NODE_BIN