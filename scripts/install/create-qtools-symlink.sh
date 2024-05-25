#!/bin/bash

if [ -f "$QTOOLS_BIN_PATH" ]; then
    rm $QTOOLS_BIN_PATH
fi

ln -s $QTOOLS_PATH/qtools.sh $QTOOLS_BIN_PATH