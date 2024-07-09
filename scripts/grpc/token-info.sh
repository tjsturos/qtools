#!/bin/bash
# HELP: Gets this node's token info.

grpcurl -plaintext localhost:8337 quilibrium.node.node.pb.NodeService.GetTokenInfo
