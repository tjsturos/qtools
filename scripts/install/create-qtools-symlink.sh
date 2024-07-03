#!/bin/bash

if [ -L "$QTOOLS_BIN_PATH" ]; then
    sudo rm $QTOOLS_BIN_PATH
fi

sudo ln -s $QTOOLS_PATH/qtools.sh $QTOOLS_BIN_PATH