#!/bin/bash
# HELP: Prints details about this node.

grpcurl -plaintext localhost:8337 quilibrium.node.node.pb.NodeService.GetNodeInfo
