yq -i '.engine.dataWorkerMultiaddrs = []' $QUIL_CONFIG_FILE
yq -i '.engine.dataWorkerP2PMultiaddrs = []' $QUIL_CONFIG_FILE
yq -i '.engine.dataWorkerStreamMultiaddrs = []' $QUIL_CONFIG_FILE