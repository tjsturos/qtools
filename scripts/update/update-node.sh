#!/bin/bash
cd $QUIL_PATH

git pull
git checkout release

cd $QUIL_NODE_PATH
source ./release_autorun.sh
