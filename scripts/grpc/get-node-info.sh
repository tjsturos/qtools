#!/bin/bash

cd $QUIL_NODE_PATH && GOEXPERIMENT=arenas go run ./... -node-info
# grpcurl -plaintext localhost:8337 quilibrium.node.node.pb.NodeService.GetNodeInfo
