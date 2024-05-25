#!/bin/bash

install_package unzip zip
rm -r $QUIL_NODE_PATH/.config/store 
wget -qO- https://snapshots.cherryservers.com/quilibrium/store.zip > /tmp/store.zip 
unzip -j -o /tmp/store.zip -d $QUIL_NODE_PATH/.config/store 
rm /tmp/store.zip