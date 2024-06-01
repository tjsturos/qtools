#!/bin/bash

echo "$(grpcurl -plaintext localhost:8337 quilibrium.node.node.pb.NodeService.GetNodeInfo | grep -oP '"peerId":\s*"\K[^"]+')"
