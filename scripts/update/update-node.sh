#!/bin/bash
cd $QUIL_PATH

git pull
git checkout release

qtools start

# force a restart for when the version doesn't change, but the binary does
qtools restart