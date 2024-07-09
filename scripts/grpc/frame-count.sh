#!/bin/bash
# HELP: Prints the current frame count.

echo "$(grpcurl -plaintext localhost:8337 quilibrium.node.node.pb.NodeService.GetNodeInfo | grep -oP '"maxFrame":\s*"\K[^"]+')"
