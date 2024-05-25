#!/bin/bash
cd $QUIL_PATH

git pull
git checkout release

$QUIL_NODE_PATH/release_autorun.sh
